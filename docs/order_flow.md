# 注文〜発送フロー

注文は2パターンある:
1. **アプリ内（新フロー）**: アプリで注文→決済→写真送信が完結（v1.1.2〜）。下記「【新方式】注文処理」。
2. **DM直接購入**: SNSのDMで購入希望が来た場合の手動運用。下記「番外：DM直接購入」。

> ※旧「Stripe決済＋Googleフォーム写真送付」方式は新フロー移行に伴い**廃止**。手順が必要になった場合は **git履歴**（本ファイルの過去バージョン）を参照。

## 商品・価格

| 商品 | 価格（税込・送料込） | Stripe商品名 |
|------|---------------------|-------------|
| カード | ¥2,280 | うちの子免許証カード（PVC製） |
| タグ | ¥2,480 | うちの子タグ（レジン製） |
| セット | ¥3,980 | うちの子免許証 カード＋タグセット |
| NFC代行 | +¥500 | Stripe請求書で個別請求 |

## 発送方法
- クリックポスト: 185円（追跡あり・ポスト投函）
- プチプチで梱包

---

## 【新方式】注文処理（アプリ内完結方式）

> 本番Webhook稼働済み（2026-06-21・本番E2E検証済み）。技術仕様・確認場所URLの詳細は `design_document.md` 8.4「本番Webhook構成と検証」「管理者の確認・突合先」を参照。

### 本物の注文の見分け方（2条件）
1. 受付番号が `UNK-YYYYMMDD-XXXXXX`（`UNK-`で始まる）。`UNK-`以外（`TEST-`等）は手動テストデータ＝無視
2. `paid:true` が付いている。`paid`無し／falseは未決済＝**製造しない**

### 1件の注文を処理する手順（確認場所つき）
| 手順 | 何を確認 | どのサイトのどこ |
|---|---|---|
| 1 | 本物の注文を絞る | Firebase Console → Firestore `orders` を `paid==true` でフィルタ → 受付番号を控える |
| 2 | 写真を入手 | Firebase Console → Storage `orders/{uid}/{受付番号}/` の `image_n.png` |
| 3 | 配送先・氏名・メアド・金額 | Stripeダッシュボード → 決済で `client_reference_id`=受付番号 を検索 |
| 4 | 商品内容 | Firestore の `productType`/`petNames`/`quantity`/`nfcProxy` |
| 5 | 製造・発送（NFC代行ありなら +¥500 をStripe請求書で別請求） | — |

### 確認場所URL
| 確認する物 | URL |
|---|---|
| 注文メタ＋決済記録(`paid`) | https://console.firebase.google.com/project/uchino-ko-license/firestore/databases/-default-/data/~2Forders |
| 写真本体 | https://console.firebase.google.com/project/uchino-ko-license/storage |
| 配送先・氏名・メアド・金額 | https://dashboard.stripe.com/payments |
| Webhookエンドポイント・配信ログ | https://dashboard.stripe.com/webhooks |
| 関数ログ・デプロイ状況 | https://console.firebase.google.com/project/uchino-ko-license/functions |

### 運用上の注意・手順
- **返金したとき**: 現Webhookは返金イベント（`charge.refunded`）未対応のため、Firestore `orders/{受付番号}` の `paid` は `true` のまま残る。**返金したら手動で `paid` を `false` にする（またはドキュメントを削除）**ことで製造対象から外す。
- **写真削除依頼が来たとき**: Firebase Console → Storage の `orders/{uid}/{受付番号}/` フォルダを削除する（プライバシーポリシーで「削除依頼可」と明記済み）。受付番号は問い合わせメールの件名から特定する。
- **写真の保持期間（棚卸し）**: プライバシーポリシー記載どおり「発送後30日めど」で削除する。**月1回を目安に、発送済み注文の写真フォルダを棚卸しして削除**する（現状は手動運用。注文件数が増えたら Cloud Functions スケジューラでの自動化を検討）。
- **App Check**: 現在計測モード（enforce未）。強制モード切替後は実機からの書き込みを再検証する。

---

## 番外：DM直接購入（Payment Link・手動運用）

SNSのDMで「買いたい」と来た場合の手動フロー。アプリを通さないため**受付番号が付かず、すべて手動管理**になる。

### 流れ
```
DMで購入希望 → ①商品確認 → ②Payment Link送付 → ③相手が決済
  → ④写真をDMで受領 → ⑤Stripeで入金確認＋手動突合 → ⑥制作・発送
  →（NFC代行希望なら ⑦+¥500を請求書で別請求）
```

### ① 商品確認
商品（カード/タグ/セット）・個数・どの子の写真かをDMで確認。

### ② Payment Link を送る
| 商品 | 価格 | URL |
|---|---|---|
| カード | ¥2,280 | https://buy.stripe.com/dRm3cu9kq96u8ou7Al5os01 |
| タグ | ¥2,480 | https://buy.stripe.com/7sY7sK8gm3MaeMS7Al5os00 |
| セット | ¥3,980 | https://buy.stripe.com/7sY6oGcwCdmKgV007T5os02 |

### ③ 相手が決済
URLを開く → 配送先住所・氏名・メアド・カードを入力して支払い（住所収集はリンク側で設定済み）。

### ④ 写真をDMで受領
アプリ経由でないため、免許証に使う写真をDMで送ってもらう（印刷に耐える解像度のもの）。

### ⑤ 入金確認＋突合
`https://dashboard.stripe.com/payments` で決済（金額・氏名・配送先・メアド）を確認。**受付番号が無いので、氏名・決済日時でDMの写真と手動で紐付ける**。

### ⑥ 制作・発送
写真で制作 → Stripeの配送先住所へ発送（クリックポスト等）。

### ⑦ NFC代行（+¥500・希望時のみ）
Stripeの請求書（Invoice）で別途請求:
1. `dashboard.stripe.com` → 「請求書（Invoices）」→「請求書を作成」
2. 顧客のメールアドレス（決済時のもの）を入力
3. 項目「NFC書き込み代行」¥500 を追加
4. 「送信」→ 相手のメールに請求書リンク → 相手が支払い
5. 入金確認後にNFC書き込みして発送

### 注意
- **本番決済**（実際にお金が動く）
- **受付番号が付かない**＝Firestoreに自動記録されない＝Stripe＋DMで全手動管理
- 写真の解像度を確認（印刷品質）
