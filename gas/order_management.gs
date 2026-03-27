// ============================================================
// 📦 うちの子免許証 注文管理GAS
// フォーム回答スプレッドシートに設置
// ============================================================

// ============================================================
// 設定
// ============================================================
const CONFIG = {
  // メール送信元の名前
  SENDER_NAME: 'うちの子免許証',
  // 問い合わせメール
  CONTACT_EMAIL: 'uchino.ko.license@gmail.com',
  // しゅーとへの通知先メール
  ADMIN_EMAIL: 'uchino.ko.license@gmail.com',
  // 会計スプレッドシートID
  ACCOUNTING_SHEET_ID: '1BwyyGk2YmEeXXP4pz38Psrc__-_lmidIVZuJ6Q8bl5w',
  // 商品価格
  PRICES: {
    'カード': 1980,
    'タグ': 1980,
    'カード＋タグセット': 2980,
  },
  // NFC代行料金
  NFC_PROXY_FEE: 500,
  // Stripe手数料率
  STRIPE_FEE_RATE: 0.036,
};

// フォーム回答の列定義（注文番号削除後）
// A:タイムスタンプ B:お名前 C:商品種別 D:枚数 E:画像 F:NFC代行 G:NFC内容 H:備考
const FORM_COLS = {
  TIMESTAMP: 1,    // A
  NAME: 2,         // B
  PRODUCT: 3,      // C
  QUANTITY: 4,     // D
  IMAGE: 5,        // E
  NFC_PROXY: 6,    // F
  NFC_CONTENT: 7,  // G
  NOTE: 8,         // H
};

// 管理列の定義（I列〜）
const MANAGE_COLS = {
  ORDER_ID: 9,      // I: 管理番号（自動採番）
  STATUS: 10,       // J: ステータス
  NFC_REQUEST: 11,  // K: NFC請求ステータス
  SHIP_DATE: 12,    // L: 発送日
  TRACKING: 13,     // M: 追跡番号
  MEMO: 14,         // N: メモ
  SALE_SYNCED: 15,  // O: 会計連携済み
};

// ============================================================
// 初期セットアップ（1回だけ実行）
// ============================================================
function setupOrderManagement() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheets()[0];

  // 管理列ヘッダーを追加
  const headers = [
    ['管理番号', 'ステータス', 'NFC請求', '発送日', '追跡番号', 'メモ', '会計連携'],
  ];
  sheet.getRange(1, MANAGE_COLS.ORDER_ID, 1, 7).setValues(headers);
  sheet.getRange(1, MANAGE_COLS.ORDER_ID, 1, 7)
    .setFontWeight('bold')
    .setBackground('#ff9900')
    .setFontColor('white');

  // ステータス列のドロップダウン（100行分）
  const statusRule = SpreadsheetApp.newDataValidation()
    .requireValueInList([
      '未対応', '製造中', '製造完了', '発送済', '完了', 'キャンセル'
    ], true)
    .setAllowInvalid(false)
    .build();
  sheet.getRange(2, MANAGE_COLS.STATUS, 100, 1).setDataValidation(statusRule);

  // NFC請求列のドロップダウン
  const nfcRule = SpreadsheetApp.newDataValidation()
    .requireValueInList(['なし', '未請求', '請求済', '入金済'], true)
    .setAllowInvalid(false)
    .build();
  sheet.getRange(2, MANAGE_COLS.NFC_REQUEST, 100, 1).setDataValidation(nfcRule);

  // 列幅調整
  sheet.setColumnWidth(MANAGE_COLS.ORDER_ID, 100);
  sheet.setColumnWidth(MANAGE_COLS.STATUS, 100);
  sheet.setColumnWidth(MANAGE_COLS.NFC_REQUEST, 100);
  sheet.setColumnWidth(MANAGE_COLS.SHIP_DATE, 100);
  sheet.setColumnWidth(MANAGE_COLS.TRACKING, 130);
  sheet.setColumnWidth(MANAGE_COLS.MEMO, 200);
  sheet.setColumnWidth(MANAGE_COLS.SALE_SYNCED, 80);

  // 条件付き書式: NFC代行ありの行を黄色ハイライト
  const nfcHighlight = SpreadsheetApp.newConditionalFormatRule()
    .whenTextContains('希望する')
    .setBackground('#fff2cc')
    .setRanges([sheet.getRange('A2:N101')])
    .build();

  // 条件付き書式: ステータスが「完了」の行をグレー
  const doneHighlight = SpreadsheetApp.newConditionalFormatRule()
    .whenTextEqualTo('完了')
    .setBackground('#d9d9d9')
    .setRanges([sheet.getRange('J2:J101')])
    .build();

  // 条件付き書式: ステータスが「未対応」の行を赤
  const todoHighlight = SpreadsheetApp.newConditionalFormatRule()
    .whenTextEqualTo('未対応')
    .setFontColor('#cc0000')
    .setBold(true)
    .setRanges([sheet.getRange('J2:J101')])
    .build();

  sheet.setConditionalFormatRules([nfcHighlight, doneHighlight, todoHighlight]);

  // マニュアルシート作成
  createManualSheet_(ss);

  // フォーム送信トリガーを設定
  setupTriggers_();

  SpreadsheetApp.getUi().alert(
    'セットアップ完了！\n\n' +
    '・管理列（I〜O列）を追加しました\n' +
    '・フォーム回答時に自動で管理番号が採番されます\n' +
    '・NFC代行ありの注文は黄色でハイライトされます\n' +
    '・ステータスを「発送済」に変更すると会計に自動連携されます'
  );
}

// ============================================================
// フォーム送信時の自動処理
// ============================================================
function onFormSubmit(e) {
  const sheet = e.range.getSheet();
  const row = e.range.getRow();

  // 1. 管理番号の自動採番
  const orderNum = String(row - 1).padStart(3, '0');
  const orderId = `#${orderNum}`;
  sheet.getRange(row, MANAGE_COLS.ORDER_ID).setValue(orderId);

  // 2. ステータスを「未対応」に設定
  sheet.getRange(row, MANAGE_COLS.STATUS).setValue('未対応');

  // 3. NFC代行チェック
  const nfcValue = sheet.getRange(row, FORM_COLS.NFC_PROXY).getValue();
  const hasNfc = nfcValue && nfcValue.toString().includes('希望する');
  sheet.getRange(row, MANAGE_COLS.NFC_REQUEST).setValue(hasNfc ? '未請求' : 'なし');

  // 4. 管理者に通知
  sendAdminNotificationEmail_(sheet, row, orderId, hasNfc);
}

// ============================================================
// 管理者通知メール（しゅーと向け）
// ============================================================
function sendAdminNotificationEmail_(sheet, row, orderId, hasNfc) {
  const customerName = sheet.getRange(row, FORM_COLS.NAME).getValue();
  const product = sheet.getRange(row, FORM_COLS.PRODUCT).getValue();
  const quantity = sheet.getRange(row, FORM_COLS.QUANTITY).getValue();
  const nfcContent = sheet.getRange(row, FORM_COLS.NFC_CONTENT).getValue();

  const nfcSection = hasNfc
    ? `\n⚠️ NFC書き込み代行あり（+¥500 要請求）\n書き込み内容: ${nfcContent || '（未記入）'}\n`
    : '';

  const subject = `【新規注文】${orderId} ${customerName}さん - ${product}`;
  const body = `新しい注文が入りました！\n\n` +
    `管理番号: ${orderId}\n` +
    `お名前: ${customerName}\n` +
    `商品: ${product}\n` +
    `枚数: ${quantity}\n` +
    `${nfcSection}\n` +
    `管理シート: ${SpreadsheetApp.getActiveSpreadsheet().getUrl()}\n\n` +
    `対応をお願いします。`;

  GmailApp.sendEmail(CONFIG.ADMIN_EMAIL, subject, body, {
    name: CONFIG.SENDER_NAME,
  });
}

// ============================================================
// 発送通知メール（ステータス変更時に自動送信）
// ============================================================
function onEdit(e) {
  const sheet = e.source.getActiveSheet();
  const range = e.range;
  const row = range.getRow();
  const col = range.getColumn();

  // ステータス列が「発送済」に変更された場合
  if (col === MANAGE_COLS.STATUS && e.value === '発送済' && row >= 2) {
    // 発送日を自動入力
    const today = new Date();
    sheet.getRange(row, MANAGE_COLS.SHIP_DATE).setValue(today);
    sheet.getRange(row, MANAGE_COLS.SHIP_DATE).setNumberFormat('yyyy/mm/dd');

    // 会計スプレッドシートに売上を自動記入
    syncToAccounting_(sheet, row);
  }
}

// ============================================================
// 会計スプレッドシートへの売上連携
// ============================================================
function syncToAccounting_(sheet, row) {
  const synced = sheet.getRange(row, MANAGE_COLS.SALE_SYNCED).getValue();
  if (synced === '済') return; // 重複防止

  const product = sheet.getRange(row, FORM_COLS.PRODUCT).getValue();
  const quantity = sheet.getRange(row, FORM_COLS.QUANTITY).getValue();
  const orderId = sheet.getRange(row, MANAGE_COLS.ORDER_ID).getValue();
  const hasNfc = sheet.getRange(row, MANAGE_COLS.NFC_REQUEST).getValue();
  const nfcPaid = hasNfc === '入金済';

  // 商品価格を計算
  let unitPrice = CONFIG.PRICES[product] || 0;
  let totalPrice = unitPrice * (quantity || 1);

  // NFC代行費を加算（入金済みの場合）
  if (nfcPaid) {
    totalPrice += CONFIG.NFC_PROXY_FEE;
  }

  try {
    const accSS = SpreadsheetApp.openById(CONFIG.ACCOUNTING_SHEET_ID);
    const salesSheet = accSS.getSheetByName('売上');

    // 売上シートの最終行を取得
    let lastRow = salesSheet.getLastRow();
    if (lastRow < 3) lastRow = 3;
    const newRow = lastRow + 1;

    // データを書き込み
    const today = new Date();
    salesSheet.getRange(newRow, 1).setValue(today);                              // 日付
    salesSheet.getRange(newRow, 2).setValue('mofumofu（うちの子免許証）');         // アプリ
    salesSheet.getRange(newRow, 3).setValue('物販');                              // 売上区分
    salesSheet.getRange(newRow, 4).setValue(totalPrice);                         // 売上金額
    salesSheet.getRange(newRow, 5).setValue(CONFIG.STRIPE_FEE_RATE);            // 手数料率
    salesSheet.getRange(newRow, 8).setValue(`${orderId} ${product}×${quantity}${nfcPaid ? ' +NFC代行' : ''}`); // 備考

    // 連携済みマーク
    sheet.getRange(row, MANAGE_COLS.SALE_SYNCED).setValue('済');

  } catch (e) {
    Logger.log('会計連携エラー: ' + e.toString());
    sheet.getRange(row, MANAGE_COLS.SALE_SYNCED).setValue('エラー');
  }
}

// ============================================================
// NFC代行 未請求リマインダー（毎日実行）
// ============================================================
function checkNfcReminder() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheets()[0];
  const lastRow = sheet.getLastRow();

  if (lastRow < 2) return;

  const unpaidOrders = [];

  for (let row = 2; row <= lastRow; row++) {
    const nfcStatus = sheet.getRange(row, MANAGE_COLS.NFC_REQUEST).getValue();
    const status = sheet.getRange(row, MANAGE_COLS.STATUS).getValue();
    const orderId = sheet.getRange(row, MANAGE_COLS.ORDER_ID).getValue();
    const customerName = sheet.getRange(row, FORM_COLS.NAME).getValue();

    // NFC代行が「未請求」で、ステータスが「製造完了」以降の場合
    if (nfcStatus === '未請求' && ['製造完了', '発送済'].includes(status)) {
      unpaidOrders.push(`${orderId} ${customerName}さん（ステータス: ${status}）`);
    }
  }

  if (unpaidOrders.length > 0) {
    const subject = `【リマインダー】NFC代行 未請求が${unpaidOrders.length}件あります`;
    const body = `以下の注文でNFC代行の請求がまだです：\n\n` +
      unpaidOrders.join('\n') +
      `\n\nStripeの請求書機能で¥500を請求してください。\n` +
      `管理シート: ${ss.getUrl()}`;

    GmailApp.sendEmail(CONFIG.ADMIN_EMAIL, subject, body, {
      name: CONFIG.SENDER_NAME,
    });
  }
}

// ============================================================
// マニュアルシート作成
// ============================================================
function createManualSheet_(ss) {
  // 既存のマニュアルシートがあれば削除
  const existing = ss.getSheetByName('マニュアル');
  if (existing) ss.deleteSheet(existing);

  const sheet = ss.insertSheet('マニュアル');
  sheet.setColumnWidth(1, 800);

  const manual = [
    ['📦 注文管理マニュアル'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['📌 注文〜発送の流れ'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['1. お客さんがStripeで決済 → Googleフォームで画像+情報を送信'],
    ['2. しゅーとにメール通知が届く → 管理シートを確認'],
    ['3. ステータスを「製造中」に変更 → カード印刷 / タグ製作'],
    ['4. （NFC代行ありの場合）NTAG215に書き込み → Stripeで+¥500請求'],
    ['5. 梱包 → 普通郵便（定形外）で発送'],
    ['6. ステータスを「発送済」に変更 → 発送日+会計連携が自動処理される'],
    ['7. 配達完了後「完了」に変更'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['📝 管理シートの使い方'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['■ フォーム回答列（A〜H列）— 自動入力、触らない'],
    ['  A: タイムスタンプ（フォーム送信日時）'],
    ['  B: お名前'],
    ['  C: 商品種別（カード / タグ / カード＋タグセット）'],
    ['  D: 1デザインあたりの枚数'],
    ['  E: 印刷する免許証の画像（Googleドライブリンク）'],
    ['  F: NFC書き込み代行（希望する / 空欄）'],
    ['  G: NFC書き込み内容'],
    ['  H: 備考'],
    [''],
    ['■ 管理列（I〜O列）— しゅーとが管理'],
    ['  I: 管理番号 → 自動採番（#001〜）触らない'],
    ['  J: ステータス → ドロップダウンから選択'],
    ['     未対応 → 製造中 → 製造完了 → 発送済 → 完了'],
    ['     ※キャンセルの場合は「キャンセル」を選択'],
    ['  K: NFC請求 → NFC代行ありの場合のみ操作'],
    ['     未請求 → 請求済（Stripeで請求後）→ 入金済（入金確認後）'],
    ['     ※NFC代行なしの場合は「なし」（自動設定）'],
    ['  L: 発送日 → 「発送済」にすると自動入力される'],
    ['  M: 追跡番号 → 普通郵便なら空欄でOK'],
    ['  N: メモ → 自由記入'],
    ['  O: 会計連携 → 「発送済」にすると自動で「済」になる'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['🎨 色の意味'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['  黄色の行: NFC書き込み代行あり（見落とし防止）'],
    ['  赤太字（ステータス列）: 未対応（すぐ対応が必要）'],
    ['  グレー（ステータス列）: 完了'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['💰 NFC代行の請求方法'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['1. 製造完了後、Stripeダッシュボードを開く'],
    ['2. 「請求書」→「請求書を作成」'],
    ['3. お客さんのメールアドレスを入力'],
    ['4. 商品名「NFC書き込み代行」、金額「¥500」を入力'],
    ['5. 「送信」でお客さんにメール請求'],
    ['6. 管理シートのNFC請求列を「請求済」に変更'],
    ['7. Stripeで入金確認後「入金済」に変更'],
    [''],
    ['※ 毎日9時に未請求のリマインダーメールが届きます'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['📦 発送方法'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['・普通郵便（定形外）: 120〜140円'],
    ['・プチプチで梱包して発送'],
    ['・追跡番号なし（レターパックライト370円に変更も可）'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['💲 商品・価格'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['  カード: ¥1,980（税込・送料込）'],
    ['  タグ: ¥1,980（税込・送料込）'],
    ['  カード＋タグセット: ¥2,980（税込・送料込）'],
    ['  NFC書き込み代行: +¥500（Stripe請求書で個別請求）'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['🔧 メニューの使い方'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['上部メニュー「📦 注文管理」から以下が使えます：'],
    ['  ・今月の売上サマリー → 今月の注文数・売上を表示'],
    ['  ・NFC未請求チェック → 未請求のNFC代行を確認'],
    ['  ・トリガー再設定 → 自動処理が動かないときに実行'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['🔗 関連リンク'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['  Stripeダッシュボード: https://dashboard.stripe.com'],
    ['  Googleフォーム: https://docs.google.com/forms/d/e/1FAIpQLSfSkYTQgcdnhExlgoIGxQLj_dvnTSgTbDGlpIK3Xarx6QHk-g/viewform'],
    ['  会計スプレッドシート: https://docs.google.com/spreadsheets/d/1BwyyGk2YmEeXXP4pz38Psrc__-_lmidIVZuJ6Q8bl5w/'],
    [''],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    ['❓ トラブルシューティング'],
    ['━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'],
    [''],
    ['Q: フォーム送信してもメールが来ない'],
    ['A: メニュー「📦 注文管理」→「トリガー再設定」を実行。'],
    ['   それでもダメならApps Script → トリガーを確認。'],
    [''],
    ['Q: 管理番号が自動入力されない'],
    ['A: 同上。トリガーが消えている可能性あり。'],
    [''],
    ['Q: 会計連携が「エラー」になった'],
    ['A: 会計スプレッドシートの「売上」シートが存在するか確認。'],
    ['   シート名が変わっていないか確認。'],
    [''],
    ['Q: ステータスを間違えて「発送済」にしてしまった'],
    ['A: 会計連携済み（O列が「済」）の場合、会計スプレッドシートの'],
    ['   売上シートから該当行を手動で削除。O列を空欄に戻す。'],
  ];

  manual.forEach((row, i) => {
    sheet.getRange(i + 1, 1).setValue(row[0]);
  });

  // タイトル行の書式
  sheet.getRange(1, 1).setFontSize(16).setFontWeight('bold');

  // セクションヘッダーの書式
  [4, 16, 40, 44, 57, 65, 74, 81, 88].forEach(row => {
    if (row <= manual.length) {
      sheet.getRange(row, 1).setFontSize(12).setFontWeight('bold');
    }
  });

  sheet.setFrozenRows(0);
}

// ============================================================
// 手動: 月次売上サマリーを表示
// ============================================================
function showMonthlySummary() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheets()[0];
  const lastRow = sheet.getLastRow();

  if (lastRow < 2) {
    SpreadsheetApp.getUi().alert('注文データがありません。');
    return;
  }

  const now = new Date();
  const thisMonth = now.getMonth();
  const thisYear = now.getFullYear();

  let totalSales = 0;
  let totalOrders = 0;
  let nfcCount = 0;
  const productCount = {};

  for (let row = 2; row <= lastRow; row++) {
    const timestamp = sheet.getRange(row, FORM_COLS.TIMESTAMP).getValue();
    if (!timestamp) continue;

    const date = new Date(timestamp);
    if (date.getMonth() === thisMonth && date.getFullYear() === thisYear) {
      const product = sheet.getRange(row, FORM_COLS.PRODUCT).getValue();
      const quantity = sheet.getRange(row, FORM_COLS.QUANTITY).getValue() || 1;
      const status = sheet.getRange(row, MANAGE_COLS.STATUS).getValue();

      if (status === 'キャンセル') continue;

      totalOrders++;
      const price = (CONFIG.PRICES[product] || 0) * quantity;
      totalSales += price;

      productCount[product] = (productCount[product] || 0) + quantity;

      const nfcStatus = sheet.getRange(row, MANAGE_COLS.NFC_REQUEST).getValue();
      if (nfcStatus !== 'なし') {
        nfcCount++;
        totalSales += CONFIG.NFC_PROXY_FEE;
      }
    }
  }

  const productSummary = Object.entries(productCount)
    .map(([p, c]) => `  ${p}: ${c}個`)
    .join('\n');

  SpreadsheetApp.getUi().alert(
    `📊 ${thisYear}年${thisMonth + 1}月の売上サマリー\n\n` +
    `注文数: ${totalOrders}件\n` +
    `売上合計: ¥${totalSales.toLocaleString()}\n` +
    `NFC代行: ${nfcCount}件\n\n` +
    `商品別:\n${productSummary || '  なし'}`
  );
}

// ============================================================
// トリガー設定
// ============================================================
function setupTriggers_() {
  // 既存トリガーを削除（重複防止）
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => ScriptApp.deleteTrigger(trigger));

  // フォーム送信時トリガー
  ScriptApp.newTrigger('onFormSubmit')
    .forSpreadsheet(SpreadsheetApp.getActiveSpreadsheet())
    .onFormSubmit()
    .create();

  // NFC代行リマインダー（毎日9時）
  ScriptApp.newTrigger('checkNfcReminder')
    .timeBased()
    .everyDays(1)
    .atHour(9)
    .create();
}

// ============================================================
// メニュー追加
// ============================================================
function onOpen() {
  SpreadsheetApp.getUi().createMenu('📦 注文管理')
    .addItem('初期セットアップ（最初の1回のみ）', 'setupOrderManagement')
    .addSeparator()
    .addItem('今月の売上サマリー', 'showMonthlySummary')
    .addItem('NFC未請求チェック', 'checkNfcReminder')
    .addSeparator()
    .addItem('トリガー再設定', 'setupTriggers_')
    .addToUi();
}
