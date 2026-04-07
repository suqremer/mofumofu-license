# 引き継ぎメモ（セッション終了時に上書き更新）

## 最終作業日
2026-04-07（AdMob app-ads.txt認証完了 + AdMob×Firebaseリンク完了 + NFC情報ページにApp Store導線追加・push済み）

## 現在のPhase

| Phase | 状態 | 概要 |
|-------|------|------|
| 1 基盤構築 | ✅ 完了 | App Store Connect、Codemagic、Firebase等 |
| 2 コア機能実装 | ✅ 完了 | RevenueCat課金、コスチューム47種、NFC、注文画面等 |
| 3 法務・QA | ✅ 完了 | プライバシーポリシー、利用規約、特商法、景品表示法等 |
| 4 申請提出 | ✅ 完了 | v1.0.0 App Store公開済み |
| 5 v1.0.5アップデート | 🔄 審査中 | NFC URI対応 + 写真パスバグ修正 + NFC容量対策（再submit済み、TestFlightで全項目テスト通過済み） |
| マーケ施策 | 🔄 実行中 | minne審査中、Creema公開済み |

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

## v1.0.5の変更内容（審査中）

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
| 1 | v1.0.5 審査通過待ち | — | 通常1〜2日 |
| 2 | minne 3商品の審査通過待ち | — | 通常1〜2日 |
| 3 | TikTokアカウント開設＋動画投稿 | `docs/marketing_plan.md` セクション3 | 動画案10本あり。特に#2,6,10がおすすめ |
| 4 | SNSで「Creemaに出品しました」告知 | — | Twitter/Xで開発ストーリーと共に |
| 5 | App Storeスクリーンショット改善 | `docs/marketing_plan.md` セクション4.5 | 犬猫の魅力的な作例を追加 |
| 6 | 実機で広告表示確認 | — | TestFlight or 本番アプリで広告枠に実広告が出るかチェック（数日は在庫不足の可能性あり） |
| 7 | Firebase Analyticsで`ad_impression`イベント確認 | — | 2026-04-09以降、Firebase Console→Analytics→イベントで確認（リンク反映に24〜48h） |

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

### アプリ関連
- [ ] Android版リリース時: RevenueCat Google Play APIキーの差し替え（`lib/config/iap_config.dart` の `_googleApiKey` がダミー値のまま）
- [ ] オファーコード作成（SNS紹介者にプレミアム無料プレゼント）
- [x] ~~AdMob × Firebase リンク~~ → 完了（2026-04-07、インプレッション単位の広告収益もON）
- [ ] 実機で広告表示確認（TestFlight or 本番アプリ）
- [ ] Firebase Analyticsで`ad_impression`イベント確認（2026-04-09以降）
- [x] ~~AdMob app-ads.txt設置・認証~~ → 完了（2026-04-07 認証済み）
- [x] ~~Stripe本番URL差し替え~~ → 完了（価格改定済み）
- [ ] 設定画面: プレミアム購入後の即時反映確認（別Sandboxアカウントで確認必要）

### 物理カード製造ライン
- [ ] カード裏面デザイン作成（NFC表示+QRコード配置）
- [ ] 印刷テンプレートのbleed確認（デザイン確定後）
- [ ] NTAG215カードテスト
- [ ] 印刷品質テスト
- [ ] 梱包資材調達・テスト
- [ ] クリックポスト テスト発送

### マーケ施策（実行系）
- [x] ~~ハンドメイドサイト出品（minne/Creema）~~ → minne審査中、Creema公開中
- [ ] TikTok動画投稿開始
- [ ] レビュー依頼ダイアログ実装（2枚目作成後）
- [ ] シェア時ハッシュタグ自動付与の確認・実装
- [ ] Google Playリリース準備

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
4. 直近のcommit `94441bf` までpush済み

## 注意事項
- このファイルは毎セッション終了時に上書き更新される
- バージョニングルールはCLAUDE.mdに記載済み（自動インクリメント + 確認フロー）
