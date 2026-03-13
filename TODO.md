# うちの子免許証 TODO（全45項目）

## Phase 1: 基盤構築（Day 0-3）
| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 1 | App Store Connect設定（Bundle ID・証明書・Profile） | しゅーと+Claude | Done |
| 2 | Codemagic iOS署名設定・TestFlight配信 | しゅーと+Claude | Done |
| 3 | 有料アプリ契約（銀行口座+納税フォーム） | しゅーと | Done（2026-03-12有効化確認済） |
| 4 | サポート用メールアドレス取得 | しゅーと | Done |
| 5 | Firebase Crashlytics導入 | Claude | Done |
| 6 | 写真権限拒否時の挙動確認・実装 | Claude | Done |
| 7 | 小規模事業者プログラム申請 | しゅーと | Done（2026-03-14申請済、メールでステータス通知待ち。承認後は手数料30%→15%） |
| 8 | バーチャルオフィス申込 | しゅーと | スキップ（自宅住所を使用） |
| 9 | ドメイン取得 | しゅーと | PVC事業開始前に取得（GitHub Pagesで先行） |

## Phase 2: コア機能実装（Day 3-8）
| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 10 | RevenueCatコード準備 | Claude | Done |
| 11 | RevenueCatアカウント作成+APIキー取得 | しゅーと | Done（Apple接続済、メール認証済、IAP商品`mofumofu_premium`¥300登録済、Entitlement→Offering設定完了） |
| 12 | IAP実装（RevenueCat）+ Sandbox E2Eテスト | Claude | コード修正完了（isPremium二重管理バグ修正+SDK 8.x対応）。Sandbox E2Eは#16で実機テスト |
| 13 | 累計2枚制限をRevenueCat attributes+Keychain管理 | Claude | Done（SharedPreferences+Keychain二重保存、再インストール時Keychainから復元） |
| 14 | 累計2枚制限エッジケーステスト | Claude | Done（8シナリオ検証、プレミアム時の残数バッジ非表示バグ修正） |
| 15 | エラーメッセージ日本語化・統一 | Claude | Done |
| 16 | TestFlight実機テスト（IAP Sandbox含む、随時） | しゅーと | |
| 17 | アプリアイコン作成 | しゅーと | Done（柴犬アイコン、flutter_launcher_iconsで全サイズ生成済） |
| 18 | コスチューム素材作成（Midjourney） | しゅーと | |
| 19 | コスチューム課金区分決定 | しゅーと | Done（無料12種/プレミアム47種。顔ハメ無料: 学ラン・セーラー・警察。季節限定: 12月サンタ・4月着物） |
| 20 | コスチューム画像組み込み・テスト | Claude | |

## Phase 3: 法務・ドキュメント+QA（Day 8-14）
| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 21 | プライバシーポリシー作成 | Claude | Done（RevenueCat/Crashlytics/Keychain/AdMob記載、第三者サービス一覧表付き） |
| 22 | 利用規約（ToS）作成 | Claude | Done（iOS専用に統一、既存を軽微修正） |
| 23 | 特商法表記作成 | Claude | Done（個人事業主特例で住所は請求時開示） |
| 24 | 返品ポリシー作成（IAP部分） | Claude | Done（Apple返金手順案内+トラブルシューティング付き） |
| 25 | サポートWebページ作成（GitHub Pages） | Claude | Done（docs/index.htmlに4ページリンク集約、設定画面のメール修正） |
| 26 | ダークモード対応確認 | Claude | Done（ライトモード専用、darkTheme未設定でシステムダークモードの影響なし） |
| 27 | フォント埋め込み確認 | Claude | Done（Zen Maru Gothic+Noto Sans JP をバンドル、allowRuntimeFetching=false設定） |
| 28 | kDevMode falseチェック手順確立 | Claude | Done（main.dartにリリースビルドガード: kDevMode+kUseTestAds両方チェック、trueならクラッシュ） |
| 29 | 景品表示法対応 | しゅーと | |
| 30 | 開業届・青色申告申請 | しゅーと | |

## Phase 4: 申請提出（Day 14-16）
| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 31 | スクリーンショット撮影（3サイズ） | しゅーと+Claude | ⚠️注意: 「猫＋学ラン＋免許証」の組み合わせをメインビジュアルにしない（なめ猫連想回避）。犬＋サングラス等を前面に |
| 32 | ASO（説明文・キーワード・カテゴリ） | Claude | Done（アプリ名/サブタイトル/キーワード100文字/説明文/プロモテキスト、重複ゼロ設計） |
| 33 | 審査用メモ（Review Notes）準備 | Claude | Done（チーム検証済v2: realistic-looking削除、Restore Purchases明記、ATT/Privacy Policy追記、免責強化） |
| 34 | 年齢レーティング回答 | しゅーと | Done（4+、サードパーティ広告のみ「はい」） |
| 35 | App Privacy（栄養ラベル）申告 | しゅーと+Claude | Done（7データ種別入力完了。トラッキング: デバイスID+広告データ） |
| 36 | 最終TestFlight実機テスト | しゅーと | |
| 36.5 | 申請前チーム最終レビュー（法務/ASO/技術の総点検） | Claude | 提出直前にチームで全体横断チェック。著作権/なめ猫回避/ガイドライン抵触/メタデータ整合性/IAP動作を一括検証 |
| 37 | App Store審査申請・提出 | しゅーと+Claude | |

## PVC: カード販売準備（リリース後）

### 物理カード製造ライン
| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 38 | 独自ドメイン取得+GitHub Pagesから移行 | しゅーと | |
| 39 | カード裏面デザイン作成（NFC表示+QRコード配置） | しゅーと | #38のURL確定後 |
| 40 | 印刷テンプレートのbleed確認 | Claude | #39のデザイン確定後 |
| 41 | NTAG215カードテスト | しゅーと | |
| 42 | 印刷品質テスト | しゅーと | #40完了後 |
| 43 | 梱包資材調達・テスト | しゅーと | |
| 44 | クリックポスト テスト発送 | しゅーと | #42+#43完了後 |

### 決済・注文システム（↑と並行OK）
| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 45 | Stripeアカウント開設 | しゅーと | |
| 46 | 注文フロー実装 | Claude | |
| 47 | 注文管理ワークフロー構築 | しゅーと | |
| 48 | 注文確認・発送通知メールの仕組み | しゅーと+Claude | |
| 49 | 返品ポリシー更新（PVCカード部分追加） | Claude | |
