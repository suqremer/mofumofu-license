# 引き継ぎメモ（セッション終了時に上書き更新）

## 最終作業日
2026-06-21（**Stripe Webhook 本番化完了**＝本番エンドポイント登録・本番secret設定・`firebase deploy` 完了。**本番E2E検証成功**（Closed Test内部テスト版でセット¥3,980を実カード決済→Firestore `paid`/`uploaded`/写真2枚/Stripe配送先 全確認→返金・テストデータ削除済み）。`design_document.md` 8.4 と `order_flow.md` に確認手順・URL・判断基準を追記。詳細は下記「2026-06-21」セクション）<br>
2026-06-16（v1.1.2 **Phase D＋レビュー＋Android実機/回帰テスト＋修正＋Closed Testing審査送信＋規約対応＋Webhook環境構築/コードまで完了**。最新コミット `eebe1ea`、作業ツリー clean、origin/main 同期済み。①Firebaseルール（強化版）公開済み ②App Check＝コード実装＋iOS DeviceCheck登録済み（Android後回し・計測モード）③ディープリンク＝カスタムスキーム `mofumofulicense://`・着地ページ・ホーム救済バナー。レビュー#1-9反映。Android実機テスト全合格＋不具合/改善修正済み。**1.1.2(552) を Android Closed Testing に審査送信（審査中・新フロー込み）**。**規約対応（プライバシーポリシー改訂・データセーフティ正確申告・ストア文クリーン化）完了**。**Stripe Webhook はコード＆環境構築まで完了（デプロイ未）**。**残り＝①Closed Test完走（オプトインURL配布→テスター集め→14日）②Webhookデプロイ（Stripe設定→secrets→deploy→test）③iOS実機テスト(TestFlight)＋iOS App Privacy更新 ④App Check Enforce/Android登録 ⑤NFC実機確認**。詳細は下記の各セクション）

### 2026-06-21 Stripe Webhook 本番化＋本番E2E検証完了
- **本番Webhook稼働開始**: Stripe本番モードでエンドポイント登録（名前「うちの子免許証 本番Webhook」・URL `https://us-east1-uchino-ko-license.cloudfunctions.net/stripeWebhook`・リッスン `checkout.session.completed` 1件）。本番secret（`STRIPE_SECRET_KEY`=`sk_live_…` / `STRIPE_WEBHOOK_SECRET`=本番エンドポイントの `whsec_…`）を `firebase functions:secrets:set ... --project uchino-ko-license` で設定→`firebase deploy --only functions --project uchino-ko-license` 完了。
- **本番E2E検証成功**（実カード決済）: Closed Test内部テスト版でセット注文¥3,980を実決済し、Firestore `paid:true`/`uploaded:true`/`imagePaths`2件/`amount:3980`、Storage 写真2枚、Stripe決済の配送先・氏名・メアド・金額 をすべて確認。検証後に返金・テストデータ削除済み。
- **設計書・フロー追記**: `design_document.md` 8.4 に「本番Webhook構成と検証」「管理者の確認・突合先（URL一覧）」「注文処理の判断基準（`UNK-`始まり＋`paid:true`の2条件）」。`order_flow.md` に「【新方式】注文処理（確認場所つき手順＋URL）」を併記し、旧方式に撤去予定の注記を追加。
- **リリース前レビュー対応（チーム検討反映・2026-06-21）**: ①Stripe通知「Webhook の失敗」ON済み確認＋「Webhook イベント生成の失敗」もONに（配信失敗にメールで気づける）。②**特商法・返品ポリシーへのアプリ内導線を追加**＝`lib/screens/settings_screen.dart` 法的情報セクションに「特定商取引法に基づく表記」(`/tokushoho/`)「返品ポリシー」(`/refund-policy/`)のリンクを追加（従来はプライバシー/利用規約のみで、既存の法定ページにアプリから到達できなかった）。`flutter analyze` 追加分クリーン（既存 info `settings_screen.dart:325` は kDevMode の開発用コードで無関係）。③`order_flow.md`【新方式】に返金・写真削除依頼・30日棚卸しの運用手順を追記。
- **運用注意**: ①返金してもFirestoreの`paid`は`true`のまま（現Webhookは `checkout.session.completed` のみ処理＝返金イベント未対応。返金時は手動対応）②App Checkは計測モード（enforce未）。
- ⚠️ **旧方式撤去の未来タスク（条件付き・忘れない）**: **Android製品版リリース完了 ＋ iOS版アップデート完了 の両方が揃ったら**、`order_flow.md` の旧Googleフォーム方式を撤去し【新方式】に総入れ替えする。それまでは一般ユーザーの現行運用＝旧方式のため残置。

### 2026-06-16 追加対応（規約まわり＋Webhook環境構築。最新コミット `eebe1ea`）
**規約対応（写真の外部送信に伴う必須対応・完了）:**
- プライバシーポリシー（`docs/privacy-policy/index.html`）を実態に全面改訂＝実物グッズ注文時に写真をFirebaseへ送信・保存／保持期間「発送後30日めど」／削除依頼可。最終更新2026-06-16（コミット `ea6e04d`）
- Playストア「詳しい説明」を**叩き台の丸ごと貼り付け→クリーン版に差し替え**（メタ情報削除）＋プライバシー虚偽記載修正。`docs/google_play_store_listing.md` も整理（`74cd551`）
- **データセーフティ申告を「収集しない」誤申告→正確申告に修正**（しゅーとConsole入力済み）。申告内容＝写真(収集/任意/アプリの機能)・購入履歴・おおよその位置・診断・クラッシュログ・アプリのインタラクション数・デバイスID。位置/診断/アクティビティ/デバイスIDは「共有」あり(AdMob)。暗号化はい・削除リクエスト可
  - ⚠️ **iOS の App Privacy（栄養ラベル）も同様に「写真を収集」へ更新が必要**（iOSでv1.1.2を出す時）
- 広告ID申告も完了（広告/マーケティング）

**Stripe Webhook（環境構築＋コード＝完了、デプロイは未）:**
- Node.js(v24)・Firebase CLI(15.22.0) をローカル導入。`firebase login` 済み（しゅーと手動。PowerShell実行ポリシーは `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` で解決）
- `functions/index.js`（新規）: Stripe `checkout.session.completed` を署名検証→`orders/{受付番号}` に `paid=true`等を記録（Admin SDK・最小実装）。`firebase.json`/`.firebaserc`(project=`uchino-ko-license`)/`functions/package.json` 追加。依存 install 済み
- **残り（次回）**: ①しゅーとがStripeで secret key 取得→`firebase functions:secrets:set STRIPE_SECRET_KEY`（手動・機密）②`STRIPE_WEBHOOK_SECRET` 仮設定→③`firebase deploy --only functions` でURL取得→④StripeにエンドポイントURL登録(イベント`checkout.session.completed`)→署名シークレット発行→⑤`STRIPE_WEBHOOK_SECRET`本物に更新→再deploy→⑥テスト
  - Functions リージョン= us-east1。PowerShellは毎回 `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")` でPATH再読込が必要

### Android Closed Testing（2026-06-16 審査送信）
- **方針変更（しゅーと判断）**: 当初「現行旧フロー版でClosed Test」予定だったが、**新フロー込みの 1.1.2(552) で実施**に変更。理由＝テスターは初回起動＋14日放置＋NFC書き込み程度しか触らず、新フローの未完部分（決済/写真送信）はほぼ触られない。iOS未テストもAndroidテストには無関係。Android側は実機確認済み。
- AAB は **ローカルで `flutter build appbundle --release`**（Codemagic不要）。`key.properties`で署名。kDevMode=false。
- Closed Test「Alpha」トラックに審査送信済み（日本1か国・メーリングリスト設定・広告ID申告完了「広告,マーケティング」）。**審査中**（通過でメール通知）。
- 通過後: トラックの「テスター数」タブの**オプトインURL**をテスターに配布→14日連続オプトイン（12人必須・15人募集推奨・遅れて集まる人はリスト追加でOK・リリース再公開不要）。テスターには「初回起動だけでOK、注文/決済はしないで」と案内。

※ 画面層 Phase A〜C は `e68bf14`、土台は `efbfc8b`。Phase D本体は `0731054`/`b1f3b05`、レビュー反映は `e3a718d`/`a6a6e7d`、AudioContext修正は `1b4ea69`、回帰テスト修正は `7feafd7`(fix)/`43023f7`(feat)。

### 2026-06-16 Android実機回帰テストで見つけた修正（コミット済み `7feafd7`/`43023f7`）
すべて Dart コードのため、**共通修正は次回 iOS ビルドで自動反映**（iOS側の個別作業は不要）。文字位置のみ Android 限定（iOS は元々正しいので不変）。
- 🐛 `license_painter`: Android のフォントメトリクス差で文字が上にずれる問題を補正（生年月日 -1*s／優良 Android分岐／ハンコ「子」縦書き漢字 fontSize*0.26下げ／品種は漢字含む時 -12*s／ひみつ「ひ・み・つ」平仮名 -5*s上・中点 +1*s下）。**`Platform.isAndroid` 限定・iOS不変**
- 🐛 `tag_design`: ペット名に `/` 等が含まれると丸形画像の保存に失敗→無反応になる不具合を修正（ファイル名サニタイズ＋失敗時 SnackBar）。**共通**
- `order_card/tag`: 「ご要望・備考」欄を削除（実現不可の期待防止）／NFC代行に料金 ¥500 明記。**共通**
- `order_upload`: 写真送信画面に「お支払いしていない／削除」救済導線を追加。**共通**
- `settings`/`order_upload`: お問い合わせでメールアプリが無い時にアドレスをコピー。**共通**
- `help_contents`: 注文関連3項目を新フロー（Googleフォーム廃止→アプリ内写真送信）に更新。**共通**
- ✅ 連打テスト（二度押しガード）も問題なし。NFC実機確認は後日（しゅーと）

## 🚨 別セッションのClaude へ：最初に読むべきこと

直近セッション（2026-06-16）で完了したこと（**Phase D ＋ レビュー反映・コミット＆push済み, 最新 `a6a6e7d`**）:
1. ✅ **Firebaseセキュリティルール**確定（`OrderUploadService` の実装と突合）＝`docs/design_document.md` 8.4「セキュリティルール（確定版）」が正。**しゅーとが Console に公開済み（Storage / Firestore 両方）**
2. ✅ **App Check（コード）**：`firebase_app_check ^0.3.2`（解決 0.3.2+10）追加、`lib/main.dart` の `_initFirebase` で unawaited activate（debug=debug / リリース=iOS DeviceCheck・Android Play Integrity）。**段階導入＝計測モード（Console側 Enforce はまだOFF）**
   - ✅ iOS DeviceCheck 登録済み（Apple .p8 / **Key ID `63RRL34CJ7` / Team ID `6YBWD8ZH2K`**）
   - ⏸ Android Play Integrity 登録は**後回し**（Play Consoleで「アプリの完全性」メニューが見つからず保留。計測モードゆえ実害なし。再開時は **Console 上部検索で「アプリの完全性」** を探す→Cloud project リンク→SHA-256登録）
3. ✅ **ディープリンク（カスタムスキーム方式）**：`app_links ^6.3.0`（解決 6.4.1）導入
   - iOS `Info.plist`：scheme `mofumofulicense` 登録＋`FlutterDeepLinkingEnabled=false`
   - Android `Manifest`：VIEW intent-filter（scheme `mofumofulicense`）＋`flutter_deeplinking_enabled=false`
   - `lib/services/deep_link_service.dart`（新規）：受信→pending注文を特定→1件なら`/order/upload`・他は`/order/history`
   - `lib/main.dart`：runApp 後に `DeepLinkService.instance.init()`（unawaited）
   - `lib/screens/home_screen.dart`：**ホーム救済バナー**（起動時 `getPendingOrders` 検知＝復帰の本命層。DLが不発でもアプリを開くだけで復帰可）
   - `docs/order/complete/index.html`（新規）：着地ページ（決済完了＋「アプリでお写真を送る」＝`mofumofulicense://order-return`＋手動/ストアフォールバック）
   - **方式判断**: ユニバーサルリンクではなく**カスタムスキーム**採用（iOS同一ドメイン問題回避・設定が軽くTeam ID/AASA/assetlinks/SHA不要。詳細は design_document 8.4）
4. ✅ touched Dart（main / home_screen / deep_link_service）すべて `flutter analyze` クリーン
5. ✅ **3観点レビュー（セキュリティ/正しさ/UX）実施→指摘#1-9を反映（コミット済 `e3a718d`/`a6a6e7d`）**：
   - #1 `_launchPayment` 二度押しガード＋pending保存をlaunchUrl成功後に（order_card/tag、幽霊pending・受付番号二重発番を防止）
   - #7 `setHasOrdered()` を決済時→**写真送付完了時**に移動（order_upload。離脱者を「注文済み」にしない）
   - #2 注文履歴に**削除導線**追加（既存 deleteOrder 接続。未決済pendingを消せる）
   - #3+#9 文言を中立・安心トーンに（「お支払いはお済みですか？」→「お支払いありがとうございます」等）＋「お写真」表記統一
   - #4 受付番号を `Random.secure()` に / #5 DB `CREATE TABLE IF NOT EXISTS` に
   - #6 **Firestoreルール強化**（create/update分離・docID=orderNumber一致・paid/paidAt/sessionId変更禁止）。確定版は design_document 8.4。**※Console再公開が必要（下記残り）**
   - #8 着地ページの Google Play リンクを Android製品版公開まで非表示（コメントアウト）
   - 触ったファイル analyze クリーン / order_record_test 15件パス
   - ⚠️ レビュー最大の発見＝**決済の裏取りが無い**（Webhook未実装のため未決済でも uploaded=true が書ける）。Webhook実装まで「uploaded だけで製造しない・必ずStripe入金と突合」を運用ルールとする
6. ✅ **Android実機テスト全合格**（CPH2797・debugビルド `flutter run`）：
   - テスト1 カスタムスキーム＝`adb am start -d mofumofulicense://order-return` でアプリ起動→app_links受信(`Handled intent`)→注文履歴へ遷移 ✅
   - テスト2 救済バナー＝注文(pending保存)→force-stop→コールド起動→ホーム最上部にバナー表示 ✅（起動時 getPendingOrders 検知が実機で動作）
   - テスト3 アップロード＝バナー→送信→「お写真の送信が完了しました」(受付番号 UNK-20260616-YRGEBY・セット注文)。ルール拒否ログなし＝Firebaseルール/App Check(計測)/匿名認証 全通過 ✅
   - 🐛 **実機テストで重大バグ発見＆修正**：プレビュー画面の AudioContext が `category=ambient` + `mixWithOthers` 明示で audioplayers の新バリデーションに弾かれクラッシュ（免許証作成不可）。`mixWithOthers` 指定を削除して修正（`1b4ea69`）。※今セッションの `flutter pub get`(firebase_app_check/app_links追加)で audioplayers が 6.6.0 に上がり顕在化したと推測

しゅーと側 完了済み（2026-06-16）:
- [x] Firebaseルール（**強化版**）を Console 再公開（Storage/Firestore）
- [x] 着地ページ公開（push済み → `uchinoko-license.com/order/complete/`。Google Playリンクは Android製品版まで非表示）
- [x] Stripe Payment Link 3本のリダイレクト設定＋住所/メアド必須収集（本番モード。3本ID: card=...os01 / tag=...os00 / set=...os02）
- [x] iOS App Check（DeviceCheck）登録（Key ID `63RRL34CJ7` / Team ID `6YBWD8ZH2K`）

残り（次回以降）:
- [x] ~~Android実機テスト（Step1）~~ → **全合格（上記6参照）**
- [ ] **【次回ここから】iOS実機テスト（Codemagic手動ビルド→TestFlight）**：バージョンを 1.1.2 に上げる相談→ビルド。**iOS固有部分のみ確認すればよい**（共通Dartロジックの再確認は不要）：①🔴カスタムスキーム受信（iOSは FlutterSceneDelegate 経由＝Androidと別系統。最重要）②AudioContext修正後の音/マナーモード挙動（ambientはiOS向け設定）③App Check DeviceCheck のトークン取得 ④Firアップロード（念のため）
- [ ] Android App Check（Play Integrity）登録（後回し可。Console上部検索で「アプリの完全性」→Cloudプロジェクトリンク→SHA-256）
- [ ] App Check を計測→**Enforce 切替**（計測データ確認後）
- [ ] **Stripe Webhook（Cloud Functions）= 別タスクだがリリース前提**（paid記録・製造ゲート・突合用）。実装まで「`uploaded`だけで製造しない・必ずStripe入金と受付番号で突合」運用
- [ ] リリースは段階公開（Android Closed Testing 14日→製品版申請→**その後**に新フロー投入。詳細は本HANDOFF「リリース順序」）

次回セッション開始時、まずやること:
1. `git status` がクリーン・origin同期済みを確認（前回 `1b4ea69` まで push 済み）
2. `docs/design_document.md` 8.4 と本セクションで設計・進捗を把握
3. **iOS実機テスト（TestFlight）から再開**。バージョン1.1.2への引き上げをしゅーとに相談→Codemagic手動ビルド。確認はiOS固有部分のみ（上記「残り」参照）
4. しゅーとに「Android Closed Testing の進捗」も確認（継続宿題）
5. ⚠️ **既存テスト15件failはスコープ外の別件**（costume_test／license_template_test／pet_test／widget_test=home起動 pumpAndSettle timeout）。注文フロー刷新とは無関係。テスト追従は別タスク

## v1.1.2 注文フロー刷新（2026-06-15 設計確定・実装待ち）

**設計の全文は `docs/design_document.md` 8.4 を参照（こちらが正）。** 以下は実装・作業の段取りメモ。

### 決まったこと（要点・v3＝Webhook追加版）
- 現行「Stripe決済 + Googleフォーム」を廃止し、**アプリ内完結方式**へ。決済を唯一の入口にし、写真送付をアプリ内（Firebase Storage）で完結
- 決済はStripe外部のまま。決済成功時のみ着地ページ（GitHub Pages）へ `?session_id=...` 付きリダイレクト → タップでアプリ復帰（自動復帰は不安定なため着地ページ経由＋**受付番号手入力フォールバック**）
- **Stripe Webhook 1本（Cloud Functions）を導入**：決済成功（`checkout.session.completed`）を `orders/{受付番号}` に `paid=true` で記録＝決済の真実。署名検証必須、受信→検証→Firestore書き込みのみの最小実装。通知はStripe標準メール継続（Functionはメール送信しない）
- **データモデル**：受付番号をドキュメントID。Webhookが決済、アプリが写真を同一ドキュメントに書く。`paid`/`uploaded` で「完遂 / 決済済み・写真未達（救済対象） / 未決済（無視）」を判定 → 突合・救済・計測が自動
- 受付番号を `client_reference_id` でStripeに紐づけ（`session_id` と合わせた突合キー）
- 個人情報（住所/メアド/NFC連絡先）はStripe側に集約、Firebaseには写真とメタのみ。しゅーとは Stripe（連絡先）と Firebase（写真）の2画面を受付番号で行き来
- NFC代行の連絡先は当面メール確認（アプリは `nfcProxy` フラグのみ）。頻度増で +¥500 別SKU化を検討
- ロールバックは **Remote Config killスイッチ**。旧フォームは新フロー安定まで残す

### しゅーと側の前提作業（コード実装前/並行）
- [x] Firebase を **Blazeプラン**に切替（予算アラート¥1,000設定済み、$300無料トライアル適用・フルアカウント有効化済み）
- [x] Firebase Storage（US-EAST1・本番モード）/ Firestore（(default)・本番モード）/ 匿名認証 を有効化　※**セキュリティルールは未設定（全拒否のまま）**・**App Check未**（コード実装と一体で設定予定）
- [ ] **Cloud Functions（Stripe Webhook）環境**：Firebase CLI セットアップ、Stripeダッシュボードで Webhookエンドポイント登録＋署名シークレット設定（関数コードはClaudeが用意）
- [ ] Stripe Payment Link 3本の `after_completion` を着地ページURLにリダイレクト設定 + 住所/メアド必須収集ON
- [ ] 着地ページを `uchinoko-license.com`（GitHub Pages）に作成（決済完了・二重払い不要の明記、アプリに戻るボタン、受付番号表示、アプリ未インストール時はストアへ）
- [ ] ユニバーサルリンク設定（iOS `apple-app-site-association` / Android `assetlinks.json` を `.well-known/` に配置）。**`docs/.nojekyll` 追加必須**（Jekyllが `.well-known` を除外するため公開されない）
- [ ] Apple Developer で Associated Domains capability 有効化（Codemagic の signing/provisioning 再確認）、**Team ID 確定**
- [ ] プライバシーポリシー更新（写真をFirebaseに送信保存・保持期間/削除、返金キャンセル特約）

### アプリ実装（次回以降）
- [ ] Firebase依存追加（firebase_auth匿名/cloud_firestore/firebase_storage/firebase_app_check）。決済前に認証・App Checkを温める（「お支払いに進む」押下時に `signInAnonymously` を await、App Check activate は main で unawaited）
- [ ] ディープリンク受信実装（`app_links` 導入、iOS Associated Domains entitlement、Android VIEW intent-filter `autoVerify`、`singleTop` の `onNewIntent` 対応）→ 着地ページからの復帰で session_id 受け取り → `/order/upload` へ
- [ ] `/order/card,tag,set` を「①注文内容組み立て」に整理（カメラロール保存・フォームボタン・決済後ダイアログ削除、`_canOrder` を「保存済み」→「選択済み」に変更、NFC代行チェック・備考をアプリ内化、「お支払いに進む」で受付番号発番＋`client_reference_id`付きURL＋ローカル一時保存）
- [ ] 新規 `/order/upload`（③写真アップロード＋④完了、送信前サムネ確認、全成功後Firestore1回write・決定的ファイル名で冪等、PNG実サイズ実測の上で必要ならJPEG化、`SettableMetadata` で contentType 明示）
- [ ] 新規 `/order/history`（端末ローカル控え、`database_service.dart` `_dbVersion` 4→5、`_onCreate` と `_onUpgrade` の**両方**に CREATE TABLE）
- [ ] アプリ起動時に未送信注文（`paid=true uploaded=false`）を検知して再開導線（救済）
- [ ] **Remote Config killスイッチ**（新フロー停止→旧フォーム導線にフォールバック）
- [ ] 問い合わせ導線（完了画面・履歴・着地ページにメール、受付番号を件名に）
- [ ] Bundle ID は `com.suqremer.mofumofuLicense`（**camelCase**。AASA はこれを使う。CLAUDE.md の snake_case 記載は誤記）
- [ ] バージョン：実装時に pubspec を 1.1.2 に（しゅーと確認の上）

### 実装進捗（2026-06-15時点）

**✅ 完了・コミット済み（`efbfc8b`「feat: 注文フロー刷新v1.1.2の土台実装」）:**
- `lib/models/order_record.dart`（新規）: OrderRecord モデル＋`generateOrderNumber`（UNK-YYYYMMDD-XXXXXX、紛らわしい文字0/1/O/I/L除外）。OrderStatus(pending/uploaded)。toMap で image_paths を相対化
- `lib/services/database_service.dart`（改修）: `_dbVersion` 4→5、`order_history` テーブル（CREATE文を定数化し `_onCreate`/`_onUpgrade` 両方で共用）、注文CRUD（upsertOrder/getOrder/getAllOrders/getPendingOrders/deleteOrder）、deleteAllData に order_history 追加
- `lib/services/order_upload_service.dart`（新規）: `ensureSignedIn()`（匿名認証・決済前の温め用）＋`uploadOrder()`（全画像Storageアップロード→成功後Firestoreへ1回write、all-or-nothing・`image_{i}.png`固定で冪等）。`OrderUploadException`
- `test/models/order_record_test.dart`（新規）: テスト15件パス
- `pubspec.yaml`/`pubspec.lock`: firebase_auth ^5.4.0 / cloud_firestore ^5.6.0 / firebase_storage ^12.4.0 追加（pub get済み）

**🔧 完了・未コミット（次回まとめてコミット）:**
- `lib/screens/tag_design_screen.dart`（改修）: 丸形画像を「カメラロール保存＋bool返し」→「アプリ内保存＋パス返し」（`Navigator.pop(context, path)`、`gal` import削除、ボタン文言「この画像で決定」）
- `lib/screens/order_card_screen.dart`（刷新・カード/セット兼用）: パス返却受け（`Map<int,String> _tagImagePaths`）で中間状態を解消。カメラロール保存/フォーム/決済後ダイアログを撤去。NFC代行スイッチ（`_nfcProxy`）＋備考（`_noteController`）追加。`_launchPayment`＝受付番号発番→`_collectImagePaths`（カード=完成画像／セット=完成画像＋丸形をカードごとにペア）→`DatabaseService().upsertOrder(pending)`→`AppPreferences.setHasOrdered()`→`ensureSignedIn()`温め（失敗は握り潰し）→`client_reference_id`付きURLを launchUrl。決済後は画面内に「写真を送る」導線（`/order/upload`）を表示
- `lib/screens/order_tag_screen.dart`（刷新）: 同様。imagePaths=各カードの丸形画像。`_canOrder`=全カード丸形作成済み
- `lib/screens/order_upload_screen.dart`（新規）: confirm/uploading/done/error の4フェーズ。サムネ確認→`OrderUploadService.uploadOrder`→成功で`upsertOrder(uploaded)`→完了画面（受付番号・サマリ・発送目安・問い合わせmailto＝件名に受付番号）。失敗は`OrderUploadException`でリトライUI＋「お支払い済み・二重払い不要」明記
- `lib/screens/order_history_screen.dart`（新規）: `getAllOrders()`一覧。pendingに「写真未送信」バッジ＋「写真を送る」救済ボタン（決済済み・写真未達の救済導線）
- `lib/router.dart`: `/order/upload`（`OrderRecord`をextra）・`/order/history` 登録
- `lib/screens/order_screen.dart`: AppBarに注文履歴入口、注意書きを新フロー文言（「アプリに戻って写真を送る」）に更新
- ✅ flutter analyze：上記すべて issue ゼロ。`order_record_test` 15件パス（他の既存テストfailは別件＝冒頭🚨参照）

**✅ Phase D 完了（2026-06-16・未コミット）:** 詳細は冒頭🚨セクション参照。
- `main.dart`: App Check activate（unawaited・計測モード）＋ `DeepLinkService.init()`
- ディープリンク: **カスタムスキーム `mofumofulicense://` 採用**（ユニバーサルリンクは不採用＝iOS同一ドメイン問題回避）。`app_links` 受信→pending特定→`/order/upload`。`deep_link_service.dart` 新規。Flutter標準DLは無効化（plist/manifest）
- `home_screen.dart`: 起動時 `getPendingOrders()` 検知→ホーム救済バナー（復帰の本命層）
- セキュリティルール: **しゅーとが Firebase Console 公開済み**（確定版は design_document 8.4）。App Check iOS DeviceCheck 登録済み
- 着地ページ: `docs/order/complete/index.html`（git push で公開待ち）

**⏳ 残り（しゅーと側）:** 着地ページpush公開・Stripe Payment Link 3本のリダイレクト設定・実機テスト・Android App Check登録・App Check Enforce切替・Stripe Webhook（別タスク）

### リリース順序（審査衝突回避）
- Android Closed Testing 14日完走 → 製品版申請 → **その後**に v1.1.2 新フローを投入。iOS/Android同時には出さず段階公開。旧フォーム方式は新フロー安定まで残す（ロールバック先）

### 検証で確定した事実（再検証不要）
- Payment Link の `after_completion` リダイレクトURLに `{CHECKOUT_SESSION_ID}` を入れると、決済成功時に実際の session_id が乗る（テストモードで確認済み）
- `client_reference_id` はPayment Link URLパラメータで渡せる（取引詳細トップには出ず Checkout Session 詳細で見える）

## 現在のPhase

| Phase | 状態 | 概要 |
|-------|------|------|
| 1 基盤構築 | ✅ 完了 | App Store Connect、Codemagic、Firebase等 |
| 2 コア機能実装 | ✅ 完了 | RevenueCat課金、コスチューム47種、NFC、注文画面等 |
| 3 法務・QA | ✅ 完了 | プライバシーポリシー、利用規約、特商法、景品表示法等 |
| 4 申請提出 | ✅ 完了 | v1.0.0 App Store公開済み |
| 5 v1.0.5アップデート | ✅ 完了 | NFC URI対応 + 写真パスバグ修正 + NFC容量対策（2026-04-08 リリース済み） |
| 6 v1.0.6アップデート | ✅ 完了 | ヘルプ・よくある質問機能追加（2026-04-10 リリース済み） |
| 7 v1.0.7アップデート | ✅ 完了 | 注文画面カード画像保存バグ修正（2026-04-11 リリース済み） |
| 8 v1.0.8アップデート | ✅ 完了 | ZenMaruGothic Mediumウェイト未登録によるクラッシュ修正（2026-04-15 リリース済み） |
| 9 v1.0.9アップデート | ✅ 完了 | AnimationController dispose後操作クラッシュ修正 + 物理商品導線強化4点（2026-04-17頃 リリース済み） |
| 10 v1.1.0アップデート | ✅ 完了 | NFC独立導線追加（ホーム画面2×3グリッド + 設定画面ツールセクション、2026-04-20 リリース済み） |
| 11 Android初リリース準備 | 🔄 進行中 | Internal Testing 公開済み（2026-06-13）、レビュー反映待ち。Closed Testing 移行 → 14日テスト → 製品版申請 が残り |
| 12 v1.1.2 注文フロー刷新 | 🔄 実装ほぼ完了（実機テスト待ち・未コミット） | アプリ内完結＋Stripe Webhook。設計は `docs/design_document.md` 8.4 が正。画面層=`e68bf14`／土台=`efbfc8b`。2026-06-16 Phase D（Firebaseルール公開済み／App Check計測モード・iOS登録済み／ディープリンク=カスタムスキーム `mofumofulicense://`）実装＝**未コミット**。残りはしゅーと側（着地ページpush・Stripeリダイレクト・実機テスト・App Check Enforce切替）。詳細は冒頭🚨 |
| マーケ施策 | 🔄 実行中 | minne審査中、Creema公開済み、Instagram `@uchinoko_co` ブースト広告配信中（PCブラウザ経由でApple手数料回避、¥240/日×13日） |

## 直近セッションでの変更（2026-06-13: Play Console セットアップ完了、Internal Testing 公開）

### Play Console アプリのコンテンツ申告 11/11 完了
- プライバシーポリシー / ログイン詳細（ログイン不要）/ 広告（含む）/ コンテンツレーティング（IARC、エンタテイメントカテゴリ、暴力等なし、デジタル購入あり）/ ターゲットユーザー（13歳以上、子供向けではない）/ データセーフティ（収集データ：写真、診断情報、クラッシュログ、広告ID、購入履歴、おおよその位置情報）/ 行政アプリ（該当なし）/ 金融取引（該当なし）/ 健康（該当なし）/ アプリのカテゴリ・連絡先 / ストア掲載情報

### ストア素材すべて準備（保存先）
| 項目 | サイズ | 保存先 |
|------|------|------|
| アプリアイコン | 512×512 PNG | `C:\Users\azu_1\mofumofu-license\assets\icon\app_icon_512.png`（1024×1024 元素材 `assets/icon/app_icon.png` から Pillow でリサイズ生成） |
| フィーチャーグラフィック | 1024×500 PNG | `C:\Users\azu_1\Desktop\🐾 うちの子免許証.png`（Canva で作成、犬の実物カード+タグ写真 + 「うちの子免許証」テキスト） |
| スマホスクショ 8枚 | 1290×2796 | `C:\Users\azu_1\Desktop\skusyo\1.png` 〜 `8.png`（iOS版から流用） |
| 7インチタブレットスクショ 8枚 | 1920×1200 | `C:\Users\azu_1\Desktop\skusyo_tablet7\1.png` 〜 `8.png`（Pillow でベージュ背景中央配置に変換） |
| 10インチタブレットスクショ 8枚 | 2560×1600 | `C:\Users\azu_1\Desktop\skusyo_tablet10\1.png` 〜 `8.png`（同上） |
| プロモーション動画 | YouTube | iOS版用に作成済み動画のURLを流用 |

### ストア掲載情報の確定値
- **アプリ名**: `うちの子免許証 - ペット写真の本格カード作成`
- **短い説明（80字）**: `うちの子の写真で世界に1枚の免許証カードを作成。47種コスチューム＋6色フレームで着せ替え！NFC対応`
- **詳細な説明（4000字）**: `docs/google_play_store_listing.md` 参照
- **タグ5個**: エンタテイメント / ジョーク / フォトエディタ / ユーモア / 写真
- **連絡先メアド**: `uchino.ko.license@gmail.com`
- **連絡先ウェブサイト**: `https://uchinoko-license.com/`
- **カテゴリ**: エンターテイメント
- **プライバシーポリシーURL**: `https://uchinoko-license.com/privacy-policy/`

### Internal Testing 公開状況
- AAB アップロード成功（`com.suqremer.mofumofu_license`）
- リリース名: `1.1.1 (551) - Android初リリース`
- リリースノート記入済み
- テスターメーリングリスト「内部テスター」作成、しゅーとの `sasuke22rui1@gmail.com` 登録済み
- **現状: Google レビュー反映待ち**（数時間〜1日）
- レビュー後、Play Store でアプリ名・アイコンが正しく表示される予定
- 直接URL: `https://play.google.com/store/apps/details?id=com.suqremer.mofumofu_license`

### NFC OS自動読み取り問題の判断（修正しない方針）
- 症状: Android で NFC 書き込み成功直後、OSが別途タグを検知して「収集された新しいタグ」画面を表示
- 検討した対応案:
  - A: AndroidManifest.xml に Intent Filter追加 → ❌却下（知らない人がペットタグかざした時にPlayStoreに飛んでしまい迷子対策にならない）
  - B: 「タグから離してOKを押す」フロー追加（Flutterレベル）
  - C: enableForegroundDispatch のネイティブ実装
- **結論: 修正しない**（リリース最短優先、迷子対策機能としては正常動作）
- **実害が出たら（テスターから不満指摘・レビュー悪化等）再検討**

### 次回着手する「やりたいこと」3つ（しゅーと2026-06-13指示、優先順位確定）

#### ① 注文〜支払いフロー見直し（最優先）
- **問題**: アプリ内「注文する」→ Stripe決済 → Googleフォーム送信 の現状フローで、**70%が決済せずフォーム送信のみで終わる**（既存収益損失中）
- **原因仮説**: 「フォーム送信＝注文完了」のユーザー勘違い、フォーム導線が決済より目立つ、決済が面倒で離脱
- **解決方針（A+Bハイブリッド合意済み）**:
  1. Stripe Payment Links で「配送先住所・メアド」必須収集
  2. Stripe Receipt Email にフォーム URL 埋め込み（順序強制：決済→メール→フォーム）
  3. Googleフォームは「ペット写真送信専用」に簡素化
  4. アプリ内 order_*_screen.dart の文言・導線見直し（フォームURL直接表示やめる）
- **変更対象ファイル**:
  - `lib/screens/order_card_screen.dart`
  - `lib/screens/order_tag_screen.dart`
  - `lib/screens/order_screen.dart`
  - `docs/order_flow.md`
- **しゅーと作業**: Stripe ダッシュボードで Payment Links 設定変更、Receipt Email カスタマイズ、Googleフォーム項目簡素化

#### ② 顧客情報取得（住所・メアド）の確実化
- **問題**: 現状、Stripe決済が完了しないと顧客情報が取得できず、決済未完了の70%は顧客との連絡手段がない
- **解決**: ①の改修で同時解決（Stripe で必須収集）
- **①と一体で進める**

#### ③ Android迷子情報ページ（uchinoko-license.com/n/）に Google Play バッジ追加
- **現状**: `docs/n/index.html` に App Store バッジのみ設置（`docs/n/app-store-badge.svg`）
- **対応**: Google公式日本語版（黒）の Google Play バッジ画像を追加配置（縦並び推奨）
- **Google Play URL**: `https://play.google.com/store/apps/details?id=com.suqremer.mofumofu_license`
- **タイミング**: **Android 製品版公開後**（公開前は URL が 404）
- **工数**: 30分（バッジ画像入手 + HTML編集 + push）

### 優先順位の合意（しゅーと2026-06-13選択：案A）
- **案A採用**: ①②を即対応で v1.1.2 として iOS にも配信、Android にも反映（テスト期間中の改善コミットとして製品版申請の説得材料にする）
- 想定スケジュール:
  - Day 0-1: ①②の調査・設計（次回セッション開始時）
  - Day 2-4: 実装 + iOS Codemagic ビルド + Android AAB
  - Day 3-4: 並行で Closed Testing 準備、テスター追加募集
  - Day 5: iOS v1.1.2 リリース + Android Closed Testing 公開
  - Day 5-18: 14日テスト
  - Day 19: 製品版申請
  - Day 22-25: Google 審査
  - Day 26-30: 段階公開（同時に③のバッジ追加）
  - Day 27〜: グッズ発送

### 未push のコミット・未コミット変更
- **未push のコミット**:
  - `3c01c2a docs: プライバシーポリシーをAndroid対応版に更新` (2026-05-01のセッション後、push 認証エラーで止まったまま)
- **未コミット変更（git status で見えるはず）**:
  - `android/app/src/main/AndroidManifest.xml`: AD_ID パーミッション追加（2026-05-02のビルド時に修正）
  - `docs/google_play_store_listing.md`: 素材保存先パスを追記
  - `HANDOFF.md`: 今回（2026-06-13）の更新（次回セッション開始時にはコミット済みのはず）
- **未追跡ファイル**:
  - `docs/data_safety_declaration.md` (2026-05-01作成、データセーフティ申告メモ)
  - `docs/google_play_store_listing.md` (2026-05-01作成、ストア掲載文叩き台)
  - `docs/tester_recruitment.md` (2026-05-01作成、テスター募集セット)
  - `assets/icon/app_icon_512.png` (2026-06-13生成、Google Play用アイコン)
- **次回セッション開始時、しゅーとに「push してOK？」確認の上、まとめてpush推奨**

### push 認証エラーの注意
- 2026-05-02時点で `git push` が `Invalid username or token. Password authentication is not supported.` エラーで失敗
- しゅーと環境で GitHub の Personal Access Token 期限切れ or credential helper 問題の可能性
- 次回 push する前に解消が必要（しゅーとが GitHub Desktop / VSCode の GitHub 拡張 / `gh auth login` で対応）

---

## 直近セッションでの変更（2026-04-27〜2026-04-28: Android リリース準備対応）

### 物理商品 裏面デザインデータ整備（commit 0776c70, e1c41c6, push済み）
- カード裏面（91.6×60mm @600dpi）+ タグ裏面（Φ25mm 円形PNG @1200dpi）を `assets/print_templates/` 配下に整備
- Pillow 製の再生成スクリプト同梱（PCクラッシュで元データ失った教訓を活かしてgit管理化）

### Android リリース準備対応（commits b436635, 4dd5b00, 8e62169, c790410, 未push）

#### 写真パス Android 対応（commit b436635）
- **症状**: 作成済み免許証編集でペット画像消失、タグ用丸形画像で写真表示NG
- **原因**: `PathResolver` の `/Documents/` マーカー方式が iOS 前提、Android で `path.split('/').last` フォールバックに落ちサブディレクトリ情報消失
- **修正**: `_documentsPath` 直接アンカー方式の多段フォールバックに改修、iOS マーカーは `Platform.isIOS` ガード化
- DB マイグレーション v3/v4 も `Platform.isIOS` でガード（Android で誤発火しないよう保険）
- ユニットテスト 25 件追加（iOS/Android パスパターン網羅、冪等性検証）
- 関連修正: `license_card.dart` / `pet.dart` の toMap で `toRelative` を呼ぶ、各画面の `File()` 直渡しを `resolve()` 経由に

#### Android リリースビルド対応（commit 4dd5b00）
- **ONNX Runtime クラッシュ修正**: `android/app/proguard-rules.pro` 新規作成、ai.onnxruntime.* / Flutter / AdMob / Firebase / RevenueCat / NFC を R8 から保護。`isMinifyEnabled = true` 有効化
- **INTERNET / ACCESS_NETWORK_STATE 権限**追加（広告・課金・Firebase 通信用）
- **Google Services / Crashlytics プラグイン適用**（Mapping ファイル自動アップロード）
- `app-settings:` URL スキームを `Platform.isIOS` でガード（Android では package: でアプリ詳細画面）

#### NFC UI 文言の OS 別対応（commit 8e62169）
- 「iOSのNFCダイアログでタグをかざしてください」→「NFCタグに端末の上部をかざしてください」（読み取り画面・消去画面）
- 「iPhoneの上部にかざす」→「スマートフォンの上部にかざす」（注文画面・ヘルプ書き込み方法）
- ヘルプの「読み取り方法 - 方法2」「対応機種」を `Platform.isIOS` で出し分け（iOS 既存文言完全維持）
- `kHelpItems` を `const List` → `final List` に変更

#### 起動高速化 + UX 改善（commit c790410）
- main.dart の起動初期化を `Future.wait` で並列化（Firebase / PathResolver / AppPreferences を同時実行）
- AdManager / BackgroundRemover を `unawaited` で非ブロッキング化
- **実機計測: Android 起動時間 12〜13秒 → 1〜2秒**
- MaterialApp.builder で全画面共通のキーボード閉じ処理（背景タップ→unfocus）
- preview_screen の AudioPlayer に AudioContext 設定（マナーモード時は振動のみ、通常モードは音+振動）

#### 動作確認状況
- ✅ Android 実機で広告表示・起動高速化・キーボード閉じ・マナーモード対応 を確認
- ✅ 写真パス問題は新規データで解消確認（既存テストデータは Phase B 修正前の壊れた状態のため削除前提）
- ⏳ NFC 書き込み・読み取りは実機テスト未実施（しゅーと出先のため）
- ⏳ iOS 実機回帰テスト（v1.1.0 → v1.2.0）未実施

#### 既知の保留事項
- **RevenueCat Google Play APIキー差し替え未対応**（`lib/config/iap_config.dart` の `_googleApiKey` がダミー値、リリース前必須）
- **Google Play Console デベロッパーアカウント本人確認2項目**（しゅーと作業、Androidモバイルアプリでの確認・電話番号確認）
- **文字ズレ問題（license_painter.dart の fontFamily 未指定）** はリリース後 v1.2.x で対応予定（iOS 既存ユーザー保護のため Platform.isAndroid 限定で対応）
- **作成数2枚制限のAndroid引き継ぎ**: flutter_secure_storage の OS 仕様（iOS Keychainは残る、Android は消える）として許容、ヘルプにも明記しない方針（α回避）

## 直近セッションでの変更（2026-04-15〜2026-04-20）

### v1.1.0 NFC独立導線追加（commit 1854510, push済み, 2026-04-20 リリース済み）
- **目的**: 物理カード購入者がアプリで免許証データを作り直さずにNFC書き込み/読み取りができるよう、コレクション画面に依存しない独立ルートを追加
- **修正ファイル**:
  - `lib/screens/nfc_write_screen.dart`: `LicenseCard?` nullable化、独立起動時はペット名・品種も手入力フォーム表示
  - `lib/router.dart`: `/nfc-write` のキャストを `LicenseCard?` に変更
  - `lib/screens/home_screen.dart`: 窓口案内グリッドを 2×2 → 2×3 に拡張（NFC書き込み/読み取りを追加）
  - `lib/screens/settings_screen.dart`: サポートセクションの上に「ツール」セクション新設（NFC書き込み/読み取り配置）
  - `pubspec.yaml`: 1.0.9 → 1.1.0
- **設計判断**:
  - 既存の「コレクション → NFC」ルートは残す（両ルート並行運用）
  - card != null 時は従来通り（ペット名・品種は読み取り専用）、card == null 時のみ手入力UI表示
  - チーム議論結果: 案A（ホーム配置）+ 案B（設定配置）のダブルルート

### v1.0.9 AnimationController修正 + 物理商品導線強化（commit d8fabe4, 8d2cb50, ef11a16, 2026-04-17頃 リリース済み）
- **AnimationController dispose後操作クラッシュ修正**（Crashlytics 18件/1ユーザー）
  - `preview_screen.dart` `_playShutterEffect`: 各awaitの後にmountedチェック4箇所追加
  - `photo_select_screen.dart`: setState前にmountedチェック4箇所追加
  - `camera_guide_screen.dart`: catch内setState前にmountedチェック2箇所追加
- **物理商品導線強化4点**:
  - A-1: プレビュー画面に「うちの子を実物カードに」OutlinedButton追加（ゴールド系、フル幅）
  - B-1: ホーム画面に実物グッズ独立バナー追加（受付窓口CTA下、ゴールド系、価格¥2,280〜明示）
  - B-2: 2×2グリッドの「実物グッズ」を「ヘルプ」に差し替え
  - C-1（撤回）: コレクション詳細「注文」→「実物カードに」は文字数オーバーで2行になり、後日「注文」に戻した（commit ef11a16）
- **背景**: App Store Connect分析で物理商品購入0件問題が判明。「導線の長さ」より「商品の存在を知らない/欲しいと思ってない」が問題と判断

### v1.0.8 ZenMaruGothic Mediumウェイト未登録によるクラッシュ修正（commit a42f8ec, 2026-04-15 リリース済み）
- **クラッシュ詳細**: Crashlytics 149件/18ユーザー、v1.0.2〜v1.0.7で潜在
- **エラーメッセージ**: `GoogleFonts.config.allowRuntimeFetching is false but font ZenMaruGothic-Medium was not found in the application assets`
- **原因**: pubspec.yaml に Zen Maru Gothic は w400/w700 のみ登録、コードで w500 を要求していたため `loadFontIfNecessary` でクラッシュ
- **修正**:
  - `home_screen.dart` 2箇所: `FontWeight.w500` → `w700`（「うちの子公安委員会」ラベル）
  - `typography.dart` 1箇所: `headingSmall` の `w600` → `w700`
- **教訓**: 使用可能weightをpubspec.yamlで明示的に管理する必要がある

### v1.0.7 注文画面カード画像保存バグ修正（commit 4fb7259, push済み）
- **バグ内容**: 注文画面（カード注文・セット注文）で「カード画像をカメラロールに保存」ボタンを押すと「画像ファイルが見つかりません」エラーが出る
- **原因**: `order_card_screen.dart:666` で `card.savedImagePath`（相対パス）を直接 `File()` に渡していた。v1.0.5の相対パス化修正以降に発生
- **修正**: `card.savedImagePath` → `card.resolvedSavedImagePath`（PathResolverで絶対パスに変換）
- **影響範囲**: カード注文・セット注文の両方が修正される。タグ注文は別ルートで元から問題なし
- **全箇所調査済み**: `savedImagePath` をファイルアクセスに使ってる箇所は order_card_screen.dart の1箇所のみ（他は比較用・nullチェック用で問題なし）

### v1.0.6 ヘルプ・よくある質問機能追加（commit 6ffd60e, 00d067a, push済み）→ リリース済み
- **新規ファイル**:
  - `lib/data/help_contents.dart`: ヘルプ7項目のコンテンツデータ
  - `lib/screens/help_screen.dart`: ヘルプ一覧画面
  - `lib/screens/help_detail_screen.dart`: ヘルプ詳細画面
- **修正ファイル**:
  - `lib/router.dart`: `/help` と `/help/detail` ルート追加
  - `lib/screens/settings_screen.dart`: サポートセクション先頭に「ヘルプ・よくある質問」項目追加 + バージョン表示更新
  - `pubspec.yaml`: v1.0.5 → v1.0.6
- **ヘルプ項目（全7項目）**:
  - NFC関連（4項目）: 書き込み方法 / 読み取り方法 / 反応しないとき / 対応機種
  - 注文関連（3項目）: 注文方法 / 注文後の流れ / キャンセル
- **設計判断**:
  - 2画面構成（一覧→詳細）、Card+ListTileで設定画面と統一感
  - SelectableTextで本文長押しコピー対応
  - 「スマートフォン」表記でAndroid展開時の修正最小化（iOS固有の話だけ「iPhone」明示）
  - データはconst Listでハードコード（更新時はアプリアップデート必要）
- **状況**: 2026-04-10にCodemagicビルド完了→TestFlight実機動作確認OK→Apple審査提出済み

## 直近セッションでの変更（2026-04-09〜2026-04-10）

### Instagram公式アカウント `@uchinoko_co` 開設・看板投稿完了
- **アカウント情報**:
  - ユーザーネーム: `@uchinoko_co`（minne/Creemaと統一）
  - 表示名: 🐾うちの子ブランド🐾
  - アカウント種別: ビジネス（カテゴリ「ペット用品」）
  - プロフィール画像: レジンタグ用の丸形ペット画像（暫定。専用ロゴは別タスク）
  - プロフィールリンク: App Store `https://apps.apple.com/jp/app/うちの子免許証/id6760520451`
  - プロフィール文: 「ひとりの開発者が、すべてのペットを想って作りました。NFC内蔵カード&タグ、無料アプリでデザイン可能…」
- **投稿内容（合計15投稿）**:
  - レジンタグ 6分割看板（3列×2行 = 6枚）
  - カード 6分割看板（3列×2行 = 6枚）
  - 3枚セット: [肉球] [アプリアイコン] [肉球]
- **戦略**: 「3の倍数縛り」で看板の見栄えを永続させる運用方針
- **🚨 アクションブロック発生（2026-04-10）**:
  - 短時間に15投稿 → Instagramのスパム保護「特定のアクティビティは制限されています」発動
  - 広告用3枚セット（[丸形ペットA][カード正方形][丸形ペットB]）を投稿しようとしたがキャプション反映エラー
  - 反映されない3枚を削除済み（削除操作も警戒対象になった可能性あり）
  - **次にやること**: **24〜72時間放置**して解除待ち（明日 2026-04-11 以降に再挑戦）
  - 解除後の運用ルール: **1日1〜3投稿に抑える**
- **uchinoko_coブランドの将来構想**: うちの子免許証は第1弾。今後「うちの子」シリーズで他のアプリ・商品も展開する横断ブランドアカウント

### Instagramブースト広告（2026-04-11 出稿完了・Meta審査中）
- **戦略**: アプリDL目的（Stripe決済へのファネル設計、Stripe手数料3.6% < Creema手数料11%）
- **出稿方法**: PCブラウザの instagram.com から出稿（Apple手数料30%を回避）
- **Facebookアカウント**: 広告用に新規作成済み（Instagram広告アカウントと連携済み）
- **広告本体**: 3枚セット投稿の中央タイル（カード商品写真 `card_display.jpg`）をブースト化
- **広告設定**:
  - 目標: ウェブサイトへのアクセス（App Storeリンク）
  - ターゲット: Advantage+オン、ペット・犬・猫、18歳以上
  - 予算: ¥240/日 × 13日 = ¥3,120
  - Advantage+クリエイティブ: オフ（商品写真をそのまま表示）
  - AI生成キャプション: オフ（手動キャプションをそのまま使用）
- **📋 広告配信中のやることリスト**:
  - [ ] **審査通過後**: 何もしない。自動で配信開始される
  - [ ] **1〜3日目**: 放置（MetaのAI学習期間、データがバラついても触らない）
  - [ ] **3〜5日目**: 初回データチェック（instagram.comで広告投稿を開いて確認）
    - リーチ数（何人に表示されたか）
    - インプレッション数（何回表示されたか）
    - クリック数（App Storeリンクをタップした回数）
    - クリック率（クリック数 ÷ インプレッション数）→ 目安: 1〜3%で普通、3%以上で良好、1%未満は要改善
  - [ ] **毎日**: App Store ConnectでDL数を確認（広告開始前と後の比較、1分で終わる）
  - [ ] **広告投稿にコメントが来たら返信**（エンゲージメント向上→広告効率UP）
  - [ ] **13日目（広告終了時）**: 最終レポート確認 → 次の戦略決定
    - 総インプレッション数 / 総クリック数 / CPC（¥3,120÷クリック数）/ DL数変化
    - DL増えた＆CPC安い → 予算増やして第2ラウンド
    - DL微増＆CPC普通 → 広告クリエイティブ改善して再挑戦
    - DL変化なし → 写真・コピー・ターゲットを全面見直し
  - **⚠️ やってはいけないこと**:
    - ❌ 配信中に広告を編集・停止（AI学習がリセットされる）
    - ❌ 同じ投稿で2つ目の広告を出す（予算分散）
    - ❌ 3日以内にデータ見てパニック（AI学習中は正常）
- **キャプション設計済み**（しゅーとが投稿したい時のため再掲）:
  ```
  🐾 世界に1枚だけの「うちの子免許証」 🐾

  無料アプリでデザインして、NFC内蔵のカードがお家に届きます ✨

  ✔ 迷子対策に
  ✔ お散歩のお守りに
  ✔ うちの子との思い出に

  ペットの種類は問いません。犬・猫・うさぎ・鳥…すべてのうちの子が主役です。

  ▼ 詳細・アプリDL
  プロフィール @uchinoko_co のリンクから 👆

  #うちの子免許証
  #うちの子ブランド
  #迷子札
  #NFCタグ
  #ペットグッズ
  ```
- **両サイドの丸形ペット投稿のキャプション**:
  - 右タイル（最初に投稿）:「🐾 うちの子の毎日に、ちょっと特別を 🐾 / ひとりひとり違うから、世界に1枚だけの証を。 / #うちの子ブランド #ペットのいる暮らし #愛犬 #愛猫 #うちの子」
  - 左タイル（最後に投稿）:「🐾 すべてのうちの子へ 🐾 / 想いを込めて、ひとつひとつ手作りしています。 / #うちの子ブランド #ハンドメイド #dogstagram #catstagram #ペットグッズ」
- **⚠️ 制約**: しゅーとのアカウントはハッシュタグ5個までのエラーが出る（原因不明、5個以内で運用）

## 直近セッションでの変更（2026-04-08）

### v1.0.5 App Storeリリース完了 🎉
- 審査通過 → リリース実施
- リリース内容: NFC URI対応 / 写真パスバグ修正 / NFC文字数制限 / グッズ価格改定（v1.0.4で対応済み分含む）

## 直近セッションでの変更（2026-04-07）

### AdMob関連（管理画面のみで完結、コード変更なし）
- ✅ **app-ads.txt 認証完了**：「準備完了：アプリ内広告を配信する準備が整っています」表示確認
- ✅ **AdMob × Firebase リンク完了**：iOSアプリを既存Firebaseプロジェクトに紐付け
- ✅ **インプレッション単位の広告収益 ON**：全地域の広告収益データをFirebase Analyticsに送信

### NFC情報ページにApp Store導線を追加（commit 94441bf, push済み）
- `docs/n/index.html`：ペット情報カードの**外側・下**にアプリ紹介セクションを追加
  - エラー時にも表示される構造（`card`の中身を書き換えても残る）
  - 小見出し「うちの子免許証」+ キャッチコピー + App Storeバッジ
  - リンク先: `https://apps.apple.com/jp/app/うちの子免許証/id6760520451`
  - `target="_blank" rel="noopener"` で新規タブ
- `docs/n/app-store-badge.svg`：Apple公式日本語版バッジ（黒）を新規配置
- `docs/design_document.md` 9.6 にNFCタグをアプリプロモ媒体として活用する設計意図を記載
- Android版リリース時はGoogle Playバッジを並べて表示する方針

## v1.0.5の変更内容（2026-04-08 リリース済み）

1. **NFC URI対応**：iPhoneでアプリ不要で読み取り可能に
   - 書き込みは **URIレコード1本のみ**（容量節約のためテキストレコード併載は廃止）
   - URI形式：`https://uchinoko-license.com/n/#<Base64エンコードJSON>`
   - 読み取りは URIレコード優先 → なければテキストレコードへフォールバック（v1.0.4以前のタグの後方互換）
   - GitHub Pages（`docs/n/index.html`）でペット情報を表示
   - フラグメント方式でサーバーに個人情報が残らない設計
2. **NFC文字数制限追加**（容量オーバー対策）
   - 飼い主名: 20文字
   - 電話番号: 15文字
   - 特記事項: 60→50文字
3. **写真パスバグ修正**：アプデ後に編集画面で証明写真が消える問題
   - PathResolverにセルフヒーリング追加
   - preview_screenで保存時に相対パス化
   - DBバージョン3→4: extra_data.originalPhotoPathを相対化するマイグレーション
   - collection_screen/info_input_screenでoriginalPhotoPathを中継
4. **グッズ価格改定**：カード¥2,280 / タグ¥2,480 / セット¥3,980（v1.0.4で対応済み）

## ハンドメイド出品状況

| 商品 | minne | Creema |
|------|-------|--------|
| PVCカード ¥2,780 | 🔄 審査中 | ✅ 公開中 |
| レジンタグ ¥2,980 | 🔄 審査中 | ✅ 公開中 |
| セット ¥4,980 | 🔄 審査中 | ✅ 公開中 |

※ minneは画像設定後審査中、Creemaは公開済み

- ユーザーID: `uchinoko-co`（minne/Creema共通）
- 出品情報の全文は `docs/marketing_plan.md` セクション2参照
- アプリへの言及は規約対策で「制作プロセスの説明」として自然に組み込み済み

## Next Action（優先度順）

| # | タスク | 参照ドキュメント | 備考 |
|---|--------|----------------|------|
| 1 | **ブースト広告の経過観察** | 上記「📋 広告配信中のやることリスト」参照 | 配信開始済み。3〜5日目に初回データチェック、13日目に最終レポート。**金曜（4/17）まで様子見、配信されてなければ予算増額検討**（しゅーと2026-04-11時点の方針） |
| 2 | **次回プレゼント企画の実施**（K-1〜K-3、月1定期化） | チーム議論結果 | 4/17先着順での反省→**フォロー+リポスト抽選**方式へ変更。月1（毎月第3土曜投稿）想定。月予算¥5,000〜7,000 |
| 3 | App Store Connect スクショ/説明文/プロモテキストに物理商品訴求追加 | チーム議論結果 I-1+I-2+I-3 | コード変更なし、審査不要。ASO効果あり |
| 4 | minne 3商品の審査通過待ち | — | 通常1〜2日 |
| 5 | TikTokアカウント開設＋動画投稿 | `docs/marketing_plan.md` セクション3 | 動画案10本あり。特に#2,6,10がおすすめ |
| 6 | SNSで「Creemaに出品しました」告知 | — | Twitter/Xで開発ストーリーと共に |
| 7 | App Storeスクリーンショット改善 | `docs/marketing_plan.md` セクション4.5 | 犬猫の魅力的な作例を追加 |
| 8 | 実機で広告表示確認 | — | 本番アプリで広告枠に実広告が出るかチェック |
| 9 | Firebase Analyticsで`ad_impression`イベント確認 | — | Firebase Console→Analytics→イベントで`ad_impression`を確認 |
| 10 | dSYMファイル自動アップロード設定（Codemagic） | — | 現状dSYMが未アップロードでCrashlyticsのスタックトレースが「???」になる。今後のクラッシュ分析の精度向上のため、`codemagic.yaml` で自動アップロード設定を追加する |
| 11 | design_document.md の進捗サマリー更新（v1.0.7〜v1.1.0） | — | CLAUDE.mdルール「設計判断のみ記録」に従い、NFC独立導線の設計判断（両ルート並行運用）を9.x節に追記。進捗履歴は最小限 |

### メルカリShops検討メモ（2026-04-08 調査・申込ページ確認済み → 当面保留）
- **結論: 当面は申請不可。2027年春以降に再検討**
- **理由**: メルカリShopsは個人事業主/法人のみ受付。個人事業主申請には **過去2年以内の青色申告決算書が必須**（2026-04-08 申込ページで実物確認済み）
- しゅーとは2026年3月開業・青色申告承認申請書提出済みだが、確定申告未経験のため決算書なし
- **最短ルート**: 2026年分を2027年2〜3月に青色申告 → 決算書取得 → 2027年春以降に申請可能
- **通常メルカリ**: 2025/10/22規約改定で継続販売者は事業者扱い→個人アカウント禁止。アウト
- **手数料情報（参考、申請可能時に再利用）**: 月額0円、販売手数料10%（決済手数料込み）、振込手数料200円
- **住所開示の朗報**: 商品ページに常時表示されない（購入者が「運営者情報を請求」→ メルカリからメール開示の仕組み）。さらに非公開設定で株式会社ソウゾウの住所表示に切替可能
- **2027年春のリマインダー**: 2027年2〜3月の確定申告完了後、メルカリShops申請を再検討すること

## 関連ドキュメント

| ファイル | 内容 |
|---------|------|
| `docs/design_document.md` | 技術設計（アーキテクチャ、DB、収益構造、ロードマップ） |
| `docs/marketing_plan.md` | マーケ戦略・施策（出品情報全文、SNS、ASO、課金改善） |
| `docs/order_flow.md` | 注文〜発送の業務手順 |
| `docs/aso_text.md` | App Store説明文の確定版 |
| `docs/n/index.html` | NFCタグからのアクセス時に表示するペット情報ページ |
| `CLAUDE.md` | Claude Codeへのルール・指示 |

## 今後の未修正事項（次バージョン以降の候補）

- router.dartのextraキャスト（プロセスキル後クラッシュ、発生頻度低）
- NFC待機アニメーションが1回で止まる（UX改善レベル）
- AppPreferencesのinit前アクセス（現状問題なし）
- DB初期化のレースコンディション（現実的に発生しない）

## リリース後タスク

### Android 初リリース前必須タスク（v1.1.1 リリース判定基準）

#### 完了済み（2026-04-27〜29）
- [x] ~~**RevenueCat Google Play APIキーの差し替え**~~ → 完了（commit 1cce335、`goog_cfBXftiRYdEVnQWXOeEuwfdcswj`）
- [x] ~~**Google Play Console デベロッパーアカウント本人確認**~~ → 完了（2026-04-29、Androidモバイル確認 + 電話番号確認）
- [x] ~~keystore 暗号化バックアップ~~ → 完了（しゅーと作業）
- [x] ~~**Android 実機 NFC 書き込み・読み取りテスト**~~ → 完了（しゅーと作業）
- [x] ~~Google Play Console アプリ作成~~ → 完了（2026-04-29、`com.suqremer.mofumofu_license`、ドラフト状態）
- [x] ~~Cloud Console Service Account 作成~~ → 完了（`revenuecat-play-integration`、Pub/Sub Editor + Monitoring Viewer）
- [x] ~~Service Account JSON ダウンロード~~ → 完了（**1Password 等に保管必須、Git 厳禁**）
- [x] ~~Play Console でサービスアカウント招待~~ → 完了（財務データ・注文・キャンセル閲覧権限付与）
- [x] ~~RevenueCat に JSON アップロード + Google Play app config 作成~~ → 完了（**有効化に最大36時間**）

#### 未完了（リリース順序）

**Step 1: Play Console アプリ情報整備（しゅーと作業、数時間〜数日）**
- [ ] **アプリのストア素材作成・アップロード**
  - アイコン 512×512px（必須）
  - フィーチャーグラフィック 1024×500px（必須）
  - スクリーンショット 最低2枚〜最大8枚（必須）
- [ ] **ストア掲載文**
  - 短い説明 80字（必須）
  - 詳細な説明 4000字（必須）
- [ ] **データセーフティ申告**（必須、Play Console アンケート）
  - NFC機能、写真ライブラリ、Firebase（Analytics、Crashlytics）、AdMob 広告ID、メール（問い合わせ）の利用を申告
- [ ] **コンテンツレーティング**（必須、Play Console アンケート、約15分）
- [ ] **プライバシーポリシー URL 登録**（既存 GitHub Pages のURLを Play Console に貼り付け）
- [ ] **対象国・地域・言語の設定**

**Step 2: 課金商品登録（プレミアム ¥300 買い切り）**
- [ ] Google Play Console 「収益化セットアップ」→ アプリ内アイテム登録
- [ ] 商品ID: iOS と統一（RevenueCat ダッシュボードで確認）
- [ ] 価格: ¥300（買い切り）
- [ ] 説明文（しゅーと作成）

**Step 3: AAB アップロード**
- [ ] AAB ビルド（`flutter build appbundle --release` で `app-release.aab` 生成）
- [ ] Internal Testing トラックにアップロード
- [ ] テスター（自分の Google アカウント）で動作確認

**Step 4: クローズドテスト 15人 × 14日間（Google 必須要件）**
- 2023年11月以降の個人アカウントには 12人×14日 のクローズドテスト要件あり（2024年12月に20→12に緩和）
- 安全マージン込みで **15人募集**（離脱対策）
- [ ] Threads / Instagram でテスター募集投稿
  - お礼: テスト完了者全員にレジンタグ プレゼント（原価¥469×15人 + クリックポスト¥185×15人 = 約¥9,800）
  - 応募条件: フォロー + リプライ
  - 応募多数の場合は抽選、応募12〜15人なら全員当選
- [ ] 当選者から Gmail アドレス・氏名・配送先住所を DM 収集
- [ ] Play Console「クローズドテスト」トラック作成 + 15人のメールアドレス追加
- [ ] AAB を Closed Testing にアップロード
- [ ] オプトインリンクをテスターに送付（手順書同梱）
- [ ] 14日間継続：3日に1回テスター数モニタリング、抜けたら補欠候補に声かけ
- [ ] フィードバック収集（DMで受付）

**Step 5: 製品版申請**
- [ ] 14日経過後、Play Console「製品版へのアクセスを申請」
- [ ] 質問への回答（具体的に、抽象NG）：
  - 「テスト中にどんなフィードバックを得たか」→ 「文字位置の微調整指摘 → 7箇所修正」「起動時間長いとの声 → 並列化で1〜2秒」など具体的に
  - 「どんなバグを見つけたか」→ 「ONNX Runtime クラッシュ → ProGuard ルール追加」など
  - 「それを受けて何を変更したか」→ 修正内容を箇条書き
- [ ] Google 審査 3〜7日

**Step 6: 公開 + グッズ発送**
- [ ] Phased Release（1% → 100% 段階展開推奨）
- [ ] テスター当選者15人にレジンタグ製造・発送（クリックポスト）

#### 並行で進めること（保険・将来用）
- [ ] **DUNS番号取得**（東京商工リサーチ 3,300円・約1週間、ポモンス用の保険）
  - しゅーとは個人事業主登録済み（屋号「もふもふスタジオ」、2026-03 開業届提出済み）
  - 将来的に Google Play 組織アカウント化することで、12人テスト要件を回避可能
  - 屋号の英語表記を統一すること（DUNS と開業届で完全一致）
- [ ] **iOS 実機回帰テスト**（v1.1.0 → v1.1.1 アップデートで既存データ保持・写真表示・編集が動作するか、Codemagic ビルド完了後）

#### 既知の保留事項（リリース後対応）
- 文字ズレ問題（license_painter.dart）の Android 限定 Y 座標調整は v1.1.1 で適用済み
- 作成数2枚制限の Android 引き継ぎ問題（flutter_secure_storage の OS 仕様、許容してヘルプにも明記しない方針）

### アプリ関連
- [x] ~~Android版リリース時: ヘルプのNFC方法2(かざすだけ読み取り)の挙動を調査・修正~~ → 完了（2026-04-28、`Platform.isIOS` 分岐でiOS文言維持・Android用文言追加）
- [ ] オファーコード作成（SNS紹介者にプレミアム無料プレゼント）
- [x] ~~AdMob × Firebase リンク~~ → 完了（2026-04-07、インプレッション単位の広告収益もON）
- [x] ~~実機で広告表示確認~~ → Android 実機で表示確認済み（2026-04-28、INTERNET権限+Google Servicesプラグイン適用後）
- [ ] Firebase Analyticsで`ad_impression`イベント確認（2026-04-09以降）
- [ ] **文字ズレ問題（license_painter.dart の fontFamily 未指定）の根本対応**（リリース後 v1.2.x で `Platform.isAndroid` 分岐限定の修正、iOS 既存ユーザー保護のため）
- [ ] **AndroidManifest.xml に NDEF Intent Filter 追加検討**（NFCタグタッチでアプリ起動の選択肢、現状はブラウザで開く挙動）
- [ ] **Android NFC書き込み直後のOS自動読み取り問題**（2026-06-13 検討）
  - 症状：書き込み成功画面表示 → 即座にOSの「収集された新しいタグ」画面が出る
  - 原因：書き込み完了後にNFCタグがまだ近くにあるため、Android OSが別途タグを検知して自動読み取り発動
  - **判断：修正しない方針**（リリース最短優先、迷子対策機能としては正常動作、開発者のテスト時のみ気になるレベル）
  - 対応案（必要になったら）：
    - A. AndroidManifest.xml に Intent Filter追加 → ❌却下（知らない人がペットタグかざした時にPlayStoreに飛んでしまい迷子対策にならない）
    - B. 「タグから離してOKを押す」フロー追加（Flutterレベルで NFC セッション保持）
    - C. enableForegroundDispatch のネイティブ実装
  - **実害が出たら（テスターから不満指摘・レビュー悪化等）再検討**
- [ ] CupertinoDatePicker → showDatePicker（Android UX 改善、Android 分岐）
- [ ] Adaptive Icon / Themed Icon 設定（flutter_launcher_icons の `adaptive_icon_*` 追加）
- [ ] 未使用の `image_cropper` 依存を pubspec.yaml から削除
- [ ] 作成数2枚制限の Google Sign-In 連携（Android 引き継ぎ問題の根本解決、v1.3.x 以降検討）
- [x] ~~AdMob app-ads.txt設置・認証~~ → 完了（2026-04-07 認証済み）
- [x] ~~Stripe本番URL差し替え~~ → 完了（価格改定済み）
- [ ] 設定画面: プレミアム購入後の即時反映確認（別Sandboxアカウントで確認必要）

### 物理カード製造ライン
- [x] ~~カード裏面デザイン作成~~ → 完了（2026-04-27、`assets/print_templates/card_back.png`、QRコードはNFC一本に集約のため不採用）
- [x] ~~印刷テンプレートのbleed確認~~ → 完了（91.6×60mm @600dpi、塗り足し3mm込み、`generate_card_back.py` で再生成可能）
- [ ] NTAG215カードテスト
- [ ] 印刷品質テスト
- [ ] 梱包資材調達・テスト
- [ ] クリックポスト テスト発送

### 物理タグ製造ライン
- [x] ~~タグ裏面デザイン作成~~ → 完了（2026-04-27、`assets/print_templates/tag_back.png`、Φ25mm円形PNG @1200dpi、`generate_tag_back.py` で再生成可能）
- [ ] 印刷品質テスト（レジン越しの視認性確認）
- [ ] レジン埋め込み実装テスト

### マーケ施策（実行系）
- [x] ~~ハンドメイドサイト出品（minne/Creema）~~ → minne審査中、Creema公開中
- [ ] TikTok動画投稿開始
- [ ] レビュー依頼ダイアログ実装（2枚目作成後）
- [ ] シェア時ハッシュタグ自動付与の確認・実装
- [ ] Google Playリリース準備
- [ ] **「うちの子」ブランド専用ロゴ作成**（Instagram `@uchinoko_co` のプロフィール画像用。現在はレジンタグ用の丸形ペット画像で暫定運用中。コンセプト・制作方法・予算を別途検討）

## 友達へのプレミアム付与手順

1. 友達がアプリをインストール＆起動
2. 設定画面 → サポートID → コピーボタン → IDをLINE等で送ってもらう
3. RevenueCatダッシュボード → Customers → IDで検索
4. Grant Promotional Entitlement → 「Uchino Ko License Pro」→ Lifetime
5. 友達にアプリ再起動を依頼

## 別PCで作業引き継ぐ場合
1. `git pull` で最新を取得
2. このHANDOFF.mdを最初に読む（現状把握）
3. `docs/design_document.md` で技術設計を確認
4. 直近のcommit `1854510` までpush済み（v1.1.0 NFC独立導線追加）

## 注意事項
- このファイルは毎セッション終了時に上書き更新される
- バージョニングルールはCLAUDE.mdに記載済み（自動インクリメント + 確認フロー）
