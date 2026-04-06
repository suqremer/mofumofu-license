# 引き継ぎメモ（セッション終了時に上書き更新）

## 最終作業日
2026-04-07（minne 3商品登録完了 + marketing_plan.md に出品情報記載）

## 現在のPhase

| Phase | 状態 | 概要 |
|-------|------|------|
| 1 基盤構築 | ✅ 完了 | App Store Connect、Codemagic、Firebase等 |
| 2 コア機能実装 | ✅ 完了 | RevenueCat課金、コスチューム47種、NFC、注文画面等 |
| 3 法務・QA | ✅ 完了 | プライバシーポリシー、利用規約、特商法、景品表示法等 |
| 4 申請提出 | ✅ 完了 | v1.0.0 App Store公開済み |
| 5 v1.0.2アップデート | ✅ 完了 | バグ修正9件 + サポートID機能追加。リリース済み |
| PVC販売準備 | ⬜ リリース後 | 注文画面実装済み、物理製造ラインは未構築 |
| マーケ施策 | 🔄 実行中 | minne 3商品登録済み（非公開）。Creema未着手。詳細は `docs/marketing_plan.md` |

## Next Action（優先度順）

| # | タスク | 参照ドキュメント | 備考 |
|---|--------|----------------|------|
| 1 | minne 3商品の作品画像を撮影・設定→公開 | `docs/marketing_plan.md` セクション2 | PVCカード/レジンタグ/セット、非公開で登録済み |
| 2 | Creemaに出品（minne内容を転用） | `docs/marketing_plan.md` セクション2 | 作品名・説明文・価格はmarketing_plan.mdに全文記載済み |
| 3 | TikTokアカウント開設＋動画投稿 | `docs/marketing_plan.md` セクション3 | 動画案10本あり。特に#2,6,10がおすすめ |
| 4 | App Storeスクリーンショット改善 | `docs/marketing_plan.md` セクション4.5 | 犬猫の魅力的な作例を追加 |
| 5 | AdMob app-ads.txt認証待ち | — | `docs/app-ads.txt` 設置済み、GitHub Pages公開済み |

## 関連ドキュメント

| ファイル | 内容 |
|---------|------|
| `docs/design_document.md` | 技術設計（アーキテクチャ、DB、収益構造、ロードマップ） |
| `docs/marketing_plan.md` | マーケ戦略・施策（集客、SNS、ASO、課金改善、検討会結果） |
| `docs/order_flow.md` | 注文〜発送の業務手順 |
| `docs/aso_text.md` | App Store説明文の確定版 |
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

### マーケ施策（実行系）
- [ ] ハンドメイドサイト出品（minne/Creema）
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

## 注意事項
- このファイルは毎セッション終了時に上書き更新される
- バージョニングルールはCLAUDE.mdに記載済み（自動インクリメント + 確認フロー）
