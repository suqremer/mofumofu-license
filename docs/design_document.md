# うちの子免許証 — 実施設計書

> 最終更新: 2026-03-26

---

## 1. プロダクト概要

### 1.1 コンセプト
ペットの「うちの子免許証」を作れる iOS アプリ。証明写真風のペット写真にコスチュームを着せ、免許証デザインのカードを生成する。コメディ要素（にゃん転免許・わん転免許）と実用性（NFC迷子対策タグ）を両立。

### 1.2 ターゲットユーザー
- ペットオーナー（犬・猫メイン、うさぎ・ハムスター・鳥も対応）
- SNSでペット写真をシェアする層（20-40代女性中心）

### 1.3 競合優位性
- 「免許証」というニッチなフォーマットに特化
- コスチューム着せ替え + 背景自動削除の組み合わせ
- NFC付き実物カード/タグの物理商品展開

---

## 2. 技術スタック

| レイヤー | 技術 | バージョン |
|---------|------|-----------|
| フレームワーク | Flutter | 3.41.3 |
| 言語 | Dart | ^3.11.1 |
| 状態管理 | flutter_riverpod | ^2.6.1 |
| ルーティング | go_router | ^14.8.1 |
| ローカルDB | sqflite | ^2.4.2 |
| 課金 | RevenueCat (purchases_flutter) | ^8.9.0 |
| 広告 | Google Mobile Ads | ^5.3.0 |
| クラッシュ分析 | Firebase Crashlytics | ^4.3.2 |
| 背景削除 | image_background_remover (ONNX) | ^2.0.0 |
| NFC | nfc_manager | ^3.5.0 |
| フォント | google_fonts | ^6.2.1 |
| カメラロール保存 | gal | ^2.3.2 |
| 共有シート | share_plus | ^10.1.4 |
| セキュアストレージ | flutter_secure_storage | ^10.0.0 |

### 2.1 ビルド環境
- **Android SDK**: `C:\Android\Sdk`（非ASCIIユーザー名回避のため標準パスと異なる）
- **JAVA_HOME**: `C:\Program Files\Android\Android Studio\jbr`
- **iOS ビルド**: Codemagic CI/CD → TestFlight配信
- **Bundle ID**: `com.suqremer.mofumofu_license`

---

## 3. アーキテクチャ

### 3.1 全体構成

```
lib/
├── main.dart                    # エントリーポイント（Firebase/RevenueCat/AdMob/ONNX初期化）
├── router.dart                  # go_router ルーティング定義
├── config/                      # アプリ設定
│   ├── ad_config.dart           # AdMob広告ユニットID
│   ├── dev_config.dart          # 開発用フラグ（kDevMode等）
│   └── iap_config.dart          # RevenueCat APIキー・商品ID
├── data/                        # 静的データ
│   └── breed_data.dart          # 品種リスト
├── models/                      # データモデル
│   ├── license_card.dart        # 免許証データ
│   ├── pet.dart                 # ペット手帳データ
│   ├── costume.dart             # コスチューム定義（47種）
│   ├── costume_overlay.dart     # コスチューム配置状態
│   └── license_template.dart    # テンプレート・フレーム・免許種別定義
├── screens/                     # 画面（16画面 + editor/サブ）
│   ├── editor/                  # 写真・デコ編集画面（分割構成）
│   │   ├── photo_editor_screen.dart    # メインエディタ
│   │   ├── models/
│   │   │   ├── brush_operation.dart    # ブラシ操作モデル
│   │   │   └── brush_offset.dart       # ブラシオフセットモデル
│   │   └── painters/
│   │       ├── brush_overlay_painter.dart   # ブラシ描画
│   │       ├── guide_overlay_painter.dart   # ガイドオーバーレイ
│   │       └── photo_only_painter.dart      # 写真描画
│   ├── home_screen.dart
│   ├── collection_screen.dart
│   ├── settings_screen.dart
│   ├── shell_screen.dart        # タブシェル
│   ├── photo_select_screen.dart
│   ├── camera_guide_screen.dart
│   ├── info_input_screen.dart
│   ├── mask_edit_screen.dart     # ※未使用（editorに統合済み）
│   ├── frame_select_screen.dart
│   ├── preview_screen.dart
│   ├── pet_notebook_screen.dart
│   ├── order_screen.dart
│   ├── order_card_screen.dart    # カード注文 + セット注文（isSet）
│   ├── order_tag_screen.dart
│   └── tag_design_screen.dart
├── services/                    # ビジネスロジック
│   ├── database_service.dart    # SQLite CRUD
│   ├── license_painter.dart     # Canvas描画エンジン
│   ├── license_composer.dart    # 画像合成（2048×1292 PNG出力）
│   ├── app_preferences.dart     # SharedPreferences + Keychain
│   ├── purchase_manager.dart    # RevenueCat課金管理
│   ├── nfc_service.dart         # NFC書き込み
│   └── ad_manager.dart          # AdMob管理
├── providers/                   # Riverpod プロバイダー
│   └── database_provider.dart   # DB関連プロバイダー群
├── widgets/                     # 共通ウィジェット
│   ├── paywall_bottom_sheet.dart
│   ├── banner_ad_widget.dart
│   ├── license_card_preview.dart
│   ├── photo_crop_preview.dart  # 免許証から証明写真をクロップ表示
│   ├── product_gallery.dart     # 商品画像スライドショー
│   ├── mofumofu_button.dart
│   └── section_header.dart
└── theme/                       # デザインシステム
    ├── app_theme.dart           # Material 3 テーマ
    ├── colors.dart              # カラーパレット
    ├── typography.dart          # フォント定義
    └── spacing.dart             # 間隔・角丸定数
```

### 3.2 データフロー

```
[ユーザー操作]
     ↓
[Screen (StatefulWidget / ConsumerStatefulWidget)]
     ↓ ref.watch / ref.read
[Riverpod Provider]
     ↓
[Service Layer (DatabaseService / PurchaseManager / etc.)]
     ↓
[SQLite DB / SharedPreferences / Keychain / RevenueCat API]
```

### 3.3 画像合成パイプライン

```
ペット写真 (photoPath)
     ↓
背景自動削除 (ONNX Runtime)
     ↓
手動マスク編集 (消しゴム/投げ縄/復元ブラシ)
     ↓
コスチューム配置 (ドラッグ/ピンチ/回転)
     ↓
LicenseComposer.compose()
  ├── テンプレート背景描画 (japan / usa)
  ├── フレーム色描画 (6色)
  ├── 証明写真描画 (photoScale/Offset/Rotation適用)
  ├── コスチューム群描画 (回転+拡縮)
  ├── 顔ハメパネル描画
  ├── テキスト描画 (ペット情報/ライセンス番号/有効期限)
  └── PNG出力 (2048×1292 @2x, PVC印刷対応)
```

---

## 4. 画面一覧と遷移

### 4.1 タブ構成（ShellRoute）

| タブ | パス | 画面 | 概要 |
|------|------|------|------|
| ホーム | `/` | HomeScreen | 看板ヘッダー、受付番号札CTA、発行済みリスト |
| コレクション | `/collection` | CollectionScreen | グリッド一覧、並べ替え、削除、詳細シート |
| 設定 | `/settings` | SettingsScreen | プラン情報、サポート、法務リンク |

### 4.2 免許証作成フロー（右スライドイン）

```
/create/photo  → 写真選択/撮影
     ↓
/create/info   → ペット情報入力（ドラフト自動保存）
     ↓
/create/editor → 背景自動削除 + ブラシ編集（消しゴム/投げ縄/復元）+ コスチューム配置
     ↓
/create/frame  → フレーム色・テンプレート選択
     ↓
/create/preview → プレビュー + アニメーション + DB保存 + シェア
```

> **注**: `mask_edit_screen.dart` は router.dart に `/create/mask` ルートが残っているが、
> どの画面からも遷移しておらず実質未使用。マスク編集機能は `/create/editor` に統合済み。

### 4.3 その他の画面（フェードイン）

| パス | 画面 | 概要 |
|------|------|------|
| `/create/camera` | CameraGuideScreen | ガイド付きカメラ撮影 |
| `/pet-notebook` | PetNotebookScreen | ペット手帳（ワクチン/体重管理） |
| `/order` | OrderScreen | 注文トップ（カード/タグ/セット選択） |
| `/order/card` | OrderCardScreen | PVCカード注文 |
| `/order/tag` | OrderTagScreen | レジンタグ注文 |
| `/order/set` | OrderCardScreen(isSet) | セット注文 |
| `/order/tag-design` | TagDesignScreen | タグ用丸形画像作成 |
| `/nfc-write` | NfcWriteScreen | NFC書き込み |
| `/nfc-read` | NfcReadScreen | NFC読み取り（迷子対策） |

---

## 5. データベース設計

### 5.1 SQLite（mofumofu.db v2）

#### licenses テーブル
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER PK | 自動採番 |
| pet_name | TEXT | ペット名 |
| species | TEXT | 犬/猫/うさぎ/ハムスター/鳥/その他 |
| breed | TEXT? | 品種 |
| birth_date | TEXT? | 生年月日 |
| gender | TEXT? | ♂/♀/不明 |
| specialty | TEXT? | 特技 |
| license_type | TEXT | にゃん転/わん転/もふもふ/国際/ゴールド |
| photo_path | TEXT | トリミング済み写真パス |
| costume_id | TEXT | コスチュームID（デフォルト: gakuran） |
| frame_color | TEXT | フレーム色（デフォルト: gold） |
| template_type | TEXT | japan / usa |
| saved_image_path | TEXT? | 合成済み画像パス |
| extra_data | TEXT? | JSON拡張データ。costumeOverlays、photoScale/OffsetX/OffsetY/Rotation、photoBrightness/Contrast/Saturation、outfitId、validityId、photoBgColor を格納 |
| created_at | TEXT | ISO8601 |
| updated_at | TEXT | ISO8601 |

#### pets テーブル（ペット手帳）
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER PK | 自動採番 |
| name | TEXT | ペット名 |
| species, breed, birth_date, gender | TEXT? | 基本情報 |
| photo_path | TEXT? | 写真パス（免許証作成時に自動設定、手帳画面での手動変更不可） |
| hospital_name | TEXT? | かかりつけ病院 |
| microchip_number | TEXT? | マイクロチップ番号 |
| insurance_info | TEXT? | 保険情報 |
| memo | TEXT? | メモ |

#### vaccinations テーブル
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER PK | 自動採番 |
| pet_id | INTEGER FK | pets.id |
| vaccine_name | TEXT | ワクチン名 |
| date | TEXT | 接種日 |
| next_date | TEXT? | 次回接種日 |
| memo | TEXT? | メモ |

#### weight_logs テーブル
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER PK | 自動採番 |
| pet_id | INTEGER FK | pets.id |
| weight | REAL | 体重(kg) |
| date | TEXT | 記録日 |

> **注**: ペット手帳でペット名変更時、同名の免許証（licenses.pet_name）も `updateLicensePetName()` で自動更新される。

### 5.2 SharedPreferences + Keychain

| キー | 保存先 | 用途 |
|------|--------|------|
| ftue_completed | SharedPreferences | 初回チュートリアル完了フラグ |
| total_created_count | 両方 | 累計作成枚数（Keychain=再インストール復元用） |
| draft_* | SharedPreferences | 作成途中のドラフトデータ |
| is_premium | SharedPreferences | プレミアムフラグ（RevenueCatと同期） |

---

## 6. デザインシステム

### 6.1 カラーパレット

| 名前 | 色コード | 用途 |
|------|---------|------|
| Primary（朱赤） | #D94032 | CTAボタン、アクセント |
| Secondary（免許ブルー） | #5B8FA8 | サブアクション、情報系 |
| Accent（レトロゴールド） | #C9A84C | プレミアム系、装飾 |
| Background（公文書クリーム） | #FFFDF5 | 全画面背景 |
| Surface | #FFFFFF | カード・シート背景 |
| TextDark（墨色） | #2C2C2C | 見出し・本文 |
| TextMedium | #607D8B | 補足テキスト |
| TextLight | #B0BEC5 | プレースホルダー |
| Success | #66BB6A | 完了・成功 |
| Warning | #FFA726 | 注意 |
| Error | #EF5350 | エラー |

### 6.2 フォント

| 用途 | フォント | ウェイト |
|------|---------|---------|
| 見出し | Zen Maru Gothic | 700 (Bold) |
| 本文 | Noto Sans JP | 400 (Regular) / 600 (SemiBold) |
| 免許証テンプレート | モノスペース | 大文字スペーシング |

### 6.3 コンポーネント規約
- **ElevatedButton**: primary色、28px角丸、白文字
- **OutlinedButton**: primary枠線、16px角丸
- **カード**: 白背景、12-16px角丸、影 blur:12 offset:(0,4)
- **ボトムシート**: 24px角丸（上部のみ）、ドラッグハンドル付き

---

## 7. 課金設計

### 7.1 プラン構成

| プラン | 価格 | 内容 |
|--------|------|------|
| 無料 | ¥0 | 累計2枚まで作成、広告表示、無料コスチューム12種、無料フレーム2色 |
| プレミアム | ¥300（買い切り） | 無制限作成、広告非表示、全コスチューム47種、全フレーム6色、全テンプレート |

### 7.2 RevenueCat設定
- **Product ID**: `mofumofu_premium`（¥300 Lifetime）
- **Entitlement**: `Uchino Ko License Pro`
- **APIキー**: `appl_devqORajcICbBWJDTuWHZFRfxZW`（本番用。差し替え完了）

### 7.3 コスチューム区分（確定: 無料12種 / プレミアム35種、計47種）

**無料コスチューム（12種）**:
- 顔ハメ(3): 学ラン、セーラー服、警察官
- アクセサリー(4): キャプテン帽、パーティーハット、猫耳、メガネ
- スタンプ(5): ハート、キラキラ、白肉球、茶肉球、おさかな

**プレミアムコスチューム（35種）**: 残りすべて（アクセサリー9種+スタンプ15種+顔ハメ7種+サングラス等）

**季節限定施策**:
- 12月: サンタコスチュームを期間限定無料化
- 4月: 着物コスチュームを期間限定無料化

### 7.4 フレーム色区分
- 無料: ブラック、ブルー
- プレミアム: ゴールド、シルバー、ローズゴールド、ホログラム

---

## 8. 物理商品事業

### 8.1 商品ラインナップ

| 商品 | 価格（税込） | 仕様 |
|------|------------|------|
| PVCカード | ¥1,980 | クレジットカードサイズ、NFC付き |
| レジンタグ | ¥1,980 | Φ25mmプラ板+レジン丸型、首輪取り付け可能、NFC付き |
| セット | ¥2,980 | カード + タグ（¥980お得） |

### 8.2 PVCカード製造
- **製造方式**: 自家印刷（Canon PIXUS TS8530）
- **NFC**: NTAG215（504バイト）
- **初期投資**: ¥26,253（プリンタ所有済み、カード/NFC/ラミネート等）
- **原価/枚**: ¥453（材料¥153 + 送料¥150 + 手数料¥150）
- **粗利/枚**: ¥1,527

### 8.3 レジンタグ製造
- **製造方式**: ハンドメイド（しゅーとが制作、約25分/個）
- **材料**: 2液性エポキシレジン + プラバン芯材 + NTAG215シール + 防水フィルム
- **サイズ**: Φ33mm / 高さ6mm / 約8-12g
- **原価/個**: ¥469（材料¥121 + 送料¥150 + 手数料¥198）
- **粗利/個**: ¥1,511

### 8.4 注文フロー

各注文画面（カード/タグ/セット）はStep形式のガイド付きフローで構成:

```
Step 1: 免許証選択（チェックボックス）
     ↓
Step 2: （タグ/セット注文のみ）丸形画像を作成してカメラロールに保存
         → TagDesignScreen で編集 → galパッケージでカメラロール保存
         → 保存完了で注文画面へ true を返却（保存ステータス管理）
     ↓
Step 3: 注意事項（Googleフォームで画像を送る旨の案内）
     ↓
Step 4: Googleフォームボタン（常時表示、決済前でもアクセス可）
     ↓
Step 5: Stripe Payment Links で決済（url_launcher）
         ※ タグ/セット注文は全画像の保存完了が決済ボタン有効化の条件
     ↓
決済後: フォーム送付リマインドダイアログ表示
     ↓
しゅーとが Stripe × フォーム回答を突き合わせて制作・発送
```

> **送り忘れ対策**: Stripe決済通知とフォーム回答を照合し、
> フォーム未提出の注文にはStripeの顧客メールアドレスへ催促メールを送る。

### 8.5 タグ用丸形画像作成機能（TagDesignScreen）
- アプリ内で証明写真を Φ25mm 丸形にトリミング（25mmプラ板に貼付）
- savedImagePath から photoRect 領域をクロップしてプレビュー表示
- ドラッグ + ピンチで位置・サイズ調整
- 出力: Φ1024px PNG（~1040dpi、高解像度印刷対応）
- **カメラロールに保存**（galパッケージ、アルバム名「うちの子免許証」）+ 共有シート
- 保存完了時に `Navigator.pop(context, true)` で注文画面へ結果返却

---

## 9. NFC機能

### 9.1 書き込み内容
NDEF Text Record 形式でペット迷子情報を書き込み:
```
[ペット名]
種類: [犬/猫等]
品種: [品種]
飼い主: [飼い主名]
電話: [電話番号]
備考: [任意テキスト]
```

### 9.2 制約
- NTAG215: 最大504バイト
- リアルタイムバイトカウンター表示
- 書き込みタイムアウト: 30秒

### 9.3 対応状況
- **Android**: 実装済み（nfc_manager + Kotlin 2.x パッチ適用）
- **iOS**: 実装済み（Info.plist + Capabilities設定完了、TAG entitlement + iso14443 polling、実機テストOK）

---

## 10. 広告設計

### 10.1 AdMob設定
- **iOS App ID**: `ca-app-pub-3721612777407461~2563691647`
- **Android App ID**: `ca-app-pub-3721612777407461~6065078681`
- **表示形式**: バナー広告（コレクション画面下部）
- **プレミアムユーザー**: 広告非表示

### 10.2 UMP同意フロー
- GDPR / ATT対応の同意フロー
- タイムアウト: 10秒（実装済み）

---

## 11. 法務・コンプライアンス

### 11.1 ドキュメント（全て docs/ 配下、GitHub Pages公開）

| ドキュメント | パス | 内容 |
|------------|------|------|
| プライバシーポリシー | docs/privacy-policy/ | RevenueCat/Crashlytics/Keychain/AdMob記載 |
| 利用規約 | docs/terms/ | iOS専用 |
| 特商法表記 | docs/tokushoho/ | 個人事業主特例（住所は請求時開示） |
| 返品ポリシー | docs/refund-policy/ | Apple返金手順案内 |
| サポートページ | docs/index.html | 4ページリンク集約 |

### 11.2 App Store申請情報
- **年齢レーティング**: 4+
- **カテゴリ**: エンターテインメント
- **App Privacy**: 7データ種別申告済み（トラッキング: デバイスID + 広告データ）
- **審査用メモ**: v2作成済み（Review Notes）

### 11.3 注意事項
- 「なめ猫」連想回避: 猫+学ラン+免許証の組み合わせをメインビジュアルにしない
- 連絡先メール: uchino.ko.license@gmail.com

---

## 12. リリース前チェックリスト

| # | 項目 | 状態 |
|---|------|------|
| 1 | RevenueCat APIキーを本番用(`appl_`)に差し替え | Done |
| 2 | In-App Purchase entitlements追加（Xcode） | Done（追加不要。StoreKit IAPはプロビジョニングプロファイルで自動有効化） |
| 3 | AdMob UMP同意フローにタイムアウト追加 | Done（10秒タイムアウト実装済み） |
| 4 | NFC iOS対応（Info.plist + Capabilities） | Done（TAG entitlement + iso14443 polling、実機テストOK） |
| 5 | NFC プライバシーポリシー更新 | Done（§7 NFC機能セクション追加済み） |
| 6 | kDevMode=false / kUseTestAds=false 確認 | Done（リリースビルドガード実装済み） |
| 7 | TestFlight実機テスト（IAP Sandbox含む） | 未 |
| 8 | スクリーンショット撮影 | 進行中（7枚完成、⑦グッズ完成後に撮影） |
| 9 | 最終TestFlight + チーム最終レビュー | 未 |
| 10 | App Store審査提出 | 未 |

---

## 13. 将来実装案（ロードマップ）

### Phase A: ペット顔自動検出 + コスチューム自動配置（β機能）

**概要**: ペットの顔を検出してコスチュームを自動配置。「選ぶだけで良い感じに配置される」体験。

**技術選定**:
- **iOS**: Apple Vision `VNRecognizeAnimalsRequest`（iOS 13+、モデル同梱不要）
- **Android**: YOLOv8n TFLite（~3MBモデル同梱）
- Flutter側は `MethodChannel` で統一インターフェース

**制約**:
- バウンディングボックス（動物全体）のみ取得可能。目・鼻の座標は直接取れない
- BBの上部30-40%を「顔領域」と推定するヒューリスティックで対応
- 横向き・丸まっている場合は精度が落ちる → 手動調整でカバー

**データ構造**:
```dart
class PetFaceDetection {
  final Rect boundingBox;          // 動物全体のBB（0~1 normalized）
  final String animalType;         // 'dog', 'cat', 'unknown'
  final double confidence;         // 0.0~1.0
  final Rect estimatedFaceRegion;  // BBの上部30-40%から推定
}

enum AnchorPosition {
  aboveHead,    // 帽子・王冠
  faceCenter,   // サングラス・メガネ
  belowFace,    // 蝶ネクタイ・リボン
  freePosition, // 自動配置しない
}
```

**段階的実装**:
1. Phase 1: iOS帽子系のみ（Vision API）
2. Phase 2: Android対応（YOLOv8n）+ アンカー拡充
3. Phase 3: 複数ペット検出、ユーザー微調整データからの学習

---

### Phase B: コスチュームパック販売

**概要**: 季節・テーマ別のコスチュームパックを追加課金で販売。

**想定パック**:
- 和風パック（浴衣、羽織袴、巫女、忍者）
- ハロウィンパック（魔女帽、かぼちゃ、ドラキュラマント）
- クリスマスパック（サンタ帽、トナカイ角、雪だるまスタンプ）
- スポーツパック（野球帽、サッカーユニ、柔道着）

**価格案**: ¥120-¥200/パック（4-6種入り）

---

### Phase C: テンプレート拡充

**概要**: 免許証以外のカードテンプレートを追加。

**想定テンプレート**:
- パスポート風（うちの子パスポート）
- 学生証風（うちの子学生証）
- 名刺風（うちの子名刺）
- 診察券風（うちの子診察券）

---

### Phase D: SNS連携強化

**概要**: アプリ内からSNS投稿を最適化。

**想定機能**:
- Instagram Stories用テンプレート（9:16比率、背景ぼかし+免許証中央）
- X(Twitter)用正方形テンプレート
- TikTok用動画テンプレート（免許証発行アニメーション + BGM）
- ハッシュタグ自動付与（#うちの子免許証 #ペット免許）

---

### Phase E: ペット手帳強化

**概要**: 現在のワクチン/体重記録を拡張。

**想定機能**:
- 通院記録（病名・処方・費用）
- 食事記録（フード種類・量）
- グラフ表示（体重推移、ワクチンスケジュール）
- リマインダー通知（次回ワクチン日、フィラリア予防期間）
- ペット保険証のスキャン保存

---

### Phase F: 多言語対応

**概要**: 英語圏への展開。

**対応言語**: 英語（USテンプレートは実装済み）、韓国語、中国語（繁体字）
**課題**: コスチューム・免許種別の文化的ローカライズ

---

### Phase G: Android版リリース

**概要**: 現在iOS専用だが、Flutterのクロスプラットフォーム性を活かしてAndroid版をリリース。

**必要作業**:
- Google Play Console設定
- AdMob Android広告ユニット作成
- Google Play Billing統合（RevenueCat経由）
- NFC Android実機テスト（既に実装済み）
- スクリーンショット・ストア説明文

---

### Phase H: 注文システム高度化

**概要**: 注文数増加に伴うシステム拡張。

**段階**:
1. **現状（案C）**: Stripe Payment Links + Google フォーム（サーバー不要）
2. **中期**: 注文管理ダッシュボード（Notion or Airtable連携）
3. **長期**: Firebase Functions + Firestore でフルバックエンド化
   - アプリ内画像アップロード（Firebase Storage）
   - 注文ステータスのリアルタイム追跡
   - 発送通知のプッシュ通知

---

### Phase I: AI機能

**概要**: 生成AIを活用した付加価値機能。

**想定機能**:
- ペット写真の自動補正（明るさ・コントラスト最適化）
- ペットの品種自動判定（写真から犬種/猫種を推定）
- 「特技」のAI提案（ペットの写真や情報から面白い特技を生成）
- カスタムコスチューム生成（テキストプロンプトからコスチューム画像生成）

---

## 14. 収益モデル

### 14.1 収益源（7チャネル）

| # | 収益源 | 単価 | 状態 |
|---|--------|------|------|
| 1 | AdMob バナー広告 | eCPM ¥50-100 | 実装済み |
| 2 | プレミアム買い切り | ¥300 | 実装済み |
| 3 | コスチュームパック | ¥120-200/パック | 将来 |
| 4 | PVCカード販売 | ¥1,980/枚 | 注文画面実装済み（Stripe未連携） |
| 5 | レジンタグ販売 | ¥1,980/個 | 注文画面実装済み（Stripe未連携） |
| 6 | セット販売 | ¥2,980 | 注文画面実装済み（Stripe未連携） |
| 7 | ペット手帳プレミアム | 未定 | 将来 |

### 14.2 Year 1 収益予測（中間シナリオ）

| 項目 | 金額 |
|------|------|
| 広告収入（DAU 500 × eCPM¥80） | ¥146,000 |
| プレミアム課金（CVR 5%、DL 10,000） | ¥150,000 |
| 物理商品（月20件 × 粗利¥1,500） | ¥360,000 |
| **合計** | **約¥656,000** |

---

## 15. 開発進捗サマリー

### 完了済み
- 全画面UI実装（18画面、NFC読み取り画面追加）
- 画像合成エンジン（Canvas描画 + 2048px出力、写真回転対応）
- 背景自動削除（ONNX Runtime）
- 課金システム（RevenueCat + ¥300 Lifetime、本番キー差し替え済み）
- 広告（AdMob バナー、UMP同意フロー10秒タイムアウト）
- NFC書き込み・読み取り機能（iOS + Android両対応）
- 注文システムUI（4画面 + タグ用丸形デザイン）
- 法務ドキュメント（5ページ、NFC機能・物理商品対応済み）
- ASO / 審査メモ / App Privacy
- デコ素材（コスチューム47種確定）
- Googleフォーム作成（注文受付用）
- RevenueCat本番キー差し替え
- kDevMode / kUseTestAds リリースビルドガード

### 未完了（リリースブロッカー）
- TestFlight最終実機テスト
- スクリーンショット撮影（7枚完成、⑦グッズ完成後）
- 申請前チーム最終レビュー
- App Store審査提出

### 未完了（リリース後）
- Stripe本番URL差し替え（Stripe審査通過後）
- 物理商品製造ライン構築
- 商品写真撮影＆アプリ内画像差し替え
