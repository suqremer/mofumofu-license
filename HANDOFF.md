# 引き継ぎメモ（セッション終了時に上書き更新）

## 最終作業日
2026-04-03（セッション3回目：バグ修正9件 + サポートID機能追加 + v1.0.2リリース + AdMob対応）

## 現在のPhase

| Phase | 状態 | 概要 |
|-------|------|------|
| 1 基盤構築 | ✅ 完了 | App Store Connect、Codemagic、Firebase等 |
| 2 コア機能実装 | ✅ 完了 | RevenueCat課金、コスチューム47種、NFC、注文画面等 |
| 3 法務・QA | ✅ 完了 | プライバシーポリシー、利用規約、特商法、景品表示法等 |
| 4 申請提出 | ✅ 完了 | v1.0.0 App Store公開済み |
| 5 v1.0.2アップデート | ✅ 完了 | バグ修正9件 + サポートID機能追加。リリース済み |
| PVC販売準備 | ⬜ リリース後 | 注文画面実装済み、物理製造ラインは未構築 |

## Next Action

| # | タスク | 担当 | 備考 |
|---|--------|------|------|
| 1 | AdMob app-ads.txt認証待ち | しゅーと | `docs/app-ads.txt` 設置済み、GitHub Pages公開済み。AdMobダッシュボードで認証通るまで待つ（最大24時間） |
| 2 | 友達にプレミアムを付与する | しゅーと | RevenueCatダッシュボード → Customers → Grant Promotional Entitlement (Lifetime) |

## v1.0.2 で実施した修正内容

- 課金キャンセル時にエラーSnackBarが出る問題を修正
- ON DELETE CASCADE有効化（ペット削除時に関連データも自動削除）
- NFC Completer二重complete防止（クラッシュ防止）
- PhotoEditor Xボタンに確認ダイアログ追加（編集内容の誤消失防止）
- Paywall pop後のcontext使用を修正（クラッシュ防止）
- ui.Imageのdispose漏れを修正（メモリリーク防止）
- カメラコントローラ二重dispose修正（バックグラウンド復帰時の問題防止）
- CollectionScreen空状態ボタンに無料枠チェック追加
- NFC書き込み中にキャンセルボタン追加（フリーズ防止）
- 設定画面にサポートID表示機能を追加（RevenueCat Promotional付与用）
- 未使用import/変数/メソッドを削除してwarning 0件に

## 友達へのプレミアム付与手順

1. 友達がアプリをインストール＆起動
2. 設定画面 → サポートID → コピーボタン → IDをLINE等で送ってもらう
3. RevenueCatダッシュボード → Customers → IDで検索
4. Grant Promotional Entitlement → 「Uchino Ko License Pro」→ Lifetime
5. 友達にアプリ再起動を依頼

## 今後の未修正事項（次バージョン以降の候補）

- router.dartのextraキャスト（プロセスキル後クラッシュ、発生頻度低）
- NFC待機アニメーションが1回で止まる（UX改善レベル）
- AppPreferencesのinit前アクセス（現状問題なし）
- DB初期化のレースコンディション（現実的に発生しない）

## リリース後タスク

### アプリ関連
- [ ] Android版リリース時: RevenueCat Google Play APIキーの差し替え（`lib/config/iap_config.dart` の `_googleApiKey` がダミー値のまま）
- [ ] オファーコード作成（SNS紹介者にプレミアム無料プレゼント）
- [ ] プロモ戦略検討（ASO改善・SNS施策）
- [ ] AdMob × Firebase リンク
- [x] ~~AdMob app-ads.txt設置（`docs/app-ads.txt`、GitHub Pages経由で公開）~~ → 認証待ち
- [ ] Stripe本番URL差し替え（Stripe審査通過後）
- [ ] 設定画面: プレミアム購入後の即時反映確認（別Sandboxアカウントで確認必要）

### 物理カード製造ライン
- [ ] カード裏面デザイン作成（NFC表示+QRコード配置）
- [ ] 印刷テンプレートのbleed確認（デザイン確定後）
- [ ] NTAG215カードテスト
- [ ] 印刷品質テスト
- [ ] 梱包資材調達・テスト
- [ ] クリックポスト テスト発送

## 注意事項
- このファイルは毎セッション終了時に上書き更新される
- TODO.mdは廃止。タスク管理はこのファイルに統合済み
- バージョニングルールはCLAUDE.mdに記載済み（自動インクリメント + 確認フロー）
