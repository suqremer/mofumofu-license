# うちの子免許証 — 実施設計書

> 最終更新: 2026-04-04

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
| フレームワーク | Flutter | 3.41.6 |
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

### 2.2 新規PCセットアップ手順

```bash
# 1. リポジトリをクローン
git clone https://github.com/suqremer/mofumofu-license.git
cd mofumofu-license

# 2. 依存パッケージ取得
flutter pub get

# 3. Androidエミュレータで動作確認（iOS Simulatorはmac専用）
flutter run -d emulator-5554
```

- APIキー等は全てコード内にハードコード済み。追加の秘密鍵や.envは不要
- iOS ビルドは Codemagic（CI/CD）経由で TestFlight に配信
- Android SDK は非ASCIIユーザー名の場合 `C:\Android\Sdk` 等に配置すること

### 2.3 開発時の注意事項

- **ビルド番号**: Codemagic が自動インクリメントするため、pubspec.yaml の値は無視される。App Store Connect にアップロード失敗した場合は Codemagic の設定でビルド番号を手動で上げる
- **実機テスト必須**: NFC・カメラ・IAP（課金）はエミュレータでは動作しない。TestFlight実機で確認すること
- **AdMob**: エミュレータでは「Test Ad」表示が正常動作。本番広告はリリース後のiOS実機のみ

---

## 3. アーキテクチャ

### 3.1 全体構成

```
assets/
├── costumes/                    # コスチューム画像（47種）
├── fonts/                       # バンドルフォント（Zen Maru Gothic / Noto Sans JP）
├── product_photos/              # 商品写真（PVCカード/レジンタグ/セット、計7枚）
├── sounds/                      # 効果音
└── tutorial/                    # チュートリアルGIF（5本）

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
├── screens/                     # 画面（17画面 + editor/サブ）
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
│   ├── tag_design_screen.dart
│   ├── nfc_write_screen.dart    # NFC書き込み
│   └── nfc_read_screen.dart     # NFC読み取り
├── services/                    # ビジネスロジック
│   ├── database_service.dart    # SQLite CRUD
│   ├── license_painter.dart     # Canvas描画エンジン
│   ├── license_composer.dart    # 画像合成（2048×1292 PNG出力）
│   ├── app_preferences.dart     # SharedPreferences + Keychain
│   ├── purchase_manager.dart    # RevenueCat課金管理
│   ├── nfc_service.dart         # NFC書き込み・読み取り・消去
│   ├── ad_manager.dart          # AdMob管理（バナー + インタースティシャル）
│   └── path_resolver.dart       # ファイルパス解決（相対パス↔フルパス変換）
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

### 3.4 写真回転機能

コスチュームタブで写真の角度調整が可能。斜めに撮れた写真の補正用。

- **スライダー**: -180°〜180°（-π〜π ラジアン）、リセットボタン付き
- **2本指ジェスチャー**: ピンチ操作で拡縮と同時に回転可能
- **デッドゾーン**: 回転量が4.6°（0.08rad）未満の場合は回転しない。ただし回転開始後はデッドゾーンを無効化し、微調整を妨げない
- **スナップアシスト**: 写真回転は±1.5°、コスチューム回転は±3°で自動吸着（0°/±90°/±180°）
- **角度表示**: 回転操作中にリアルタイムで角度を数値表示。操作終了後1秒でフェードアウト
- **hapticフィードバック**: スナップ時に軽い振動で吸着を通知

### 3.5 画像パス管理

iOSではアプリアップデート時にサンドボックスのUUIDが変わるため、DBにフルパスを保存すると無効になる。
Android では Documents パスが `/data/user/0/<package>/app_flutter/...` となり、iOS の `/Documents/` マーカー方式が使えない。
これら両 OS の差異に対応するため、`PathResolver` で相対パス↔フルパスの変換を一元管理する。

- **DB保存**: 相対パスで保存（例: `licenses/license_123.png`）
- **File操作**: `PathResolver.resolve()` でDocumentsパスと結合してフルパスに復元
- **多段フォールバック方式**（v1.2.0で改修、両OS対応）:
  - チェック1: `_documentsPath` を直接アンカーとして相対化（両 OS 共通の本命）
  - チェック2: iOS のみ `/Documents/` マーカーで旧 UUID パスをセルフヒーリング（`Platform.isIOS` ガード）
  - フォールバック: ファイル名のみ（バグ検出のため debugPrint）
- **冪等性**: 既に相対パスならそのまま返す（ダブル相対化防止）
- **Documentsパスキャッシュ**: アプリ起動時に `PathResolver.init()` で1回取得してstaticに保持
- **マイグレーション**:
  - DBバージョン3で `licenses.photo_path`/`saved_image_path` と `pets.photo_path` をフルパスから相対パスに変換
  - DBバージョン4で `extra_data` JSON 内の `originalPhotoPath` も相対パス化（v1.0.5で追加）
  - v1.2.0 で v3/v4 マイグレーションを `Platform.isIOS` でガード（Android では `_documentsPath` 直接アンカー方式で透過的に解決できるため不要）
- **保存時の相対パス化**: `LicenseCard.toMap()` / `Pet.toMap()` で `PathResolver.toRelative()` を呼んで必ず相対化（v1.2.0 で追加、新規・編集どちらの経路でも絶対パスがDBに混入しないようガード）
- **読み込み時の resolve**: 各画面で `File()` に渡す前に `PathResolver.resolve()` を必ず呼ぶ（frame_select_screen / photo_editor_screen / mask_edit_screen 等）
- **写真保存先**: `Documents/photos/`（tmp/はOSに随時削除される可能性があるため使用しない）
- **ユニットテスト**: `test/services/path_resolver_test.dart` で iOS / Android パターンを網羅し冪等性も検証

---

## 4. 画面一覧と遷移

### 4.1 タブ構成（ShellRoute）

| タブ | パス | 画面 | 概要 |
|------|------|------|------|
| ホーム | `/` | HomeScreen | 看板ヘッダー、受付番号札CTA、発行済みリスト |
| コレクション | `/collection` | CollectionScreen | グリッド一覧、並べ替え、削除、詳細シート |
| 設定 | `/settings` | SettingsScreen | プラン情報、ヘルプ・よくある質問、サポートID、お問い合わせ、レビュー、不具合報告、法務リンク、データ削除 |

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

> **エディタの離脱保護**: PhotoEditorScreenでは、Xボタン・スワイプバック（PopScope）で「編集を破棄しますか？」確認ダイアログを表示。誤操作による編集内容の消失を防止。

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
| `/help` | HelpScreen | ヘルプ・よくある質問の一覧（カテゴリ別） |
| `/help/detail` | HelpDetailScreen | ヘルプ詳細（本文、SelectableTextでコピー可） |

---

## 5. データベース設計

### 5.1 SQLite（mofumofu.db v3）

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
| photo_path | TEXT NOT NULL | トリミング済み写真の相対パス（Documents/以下） |
| costume_id | TEXT | コスチュームID（デフォルト: gakuran） |
| frame_color | TEXT | フレーム色（デフォルト: gold） |
| template_type | TEXT | japan / usa |
| saved_image_path | TEXT? | 合成済み画像の相対パス（Documents/以下） |
| extra_data | TEXT? | JSON拡張データ。costumeOverlays、photoScale/OffsetX/OffsetY/Rotation、photoBrightness/Contrast/Saturation、outfitId、validityId、photoBgColor、originalPhotoPath を格納 |
| created_at | TEXT | ISO8601 |
| updated_at | TEXT | ISO8601 |

#### pets テーブル（ペット手帳）
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER PK | 自動採番 |
| name | TEXT | ペット名 |
| species | TEXT NOT NULL | 種類 |
| breed, birth_date, gender | TEXT? | 基本情報 |
| photo_path | TEXT? | 写真の相対パス（免許証作成時に自動設定、手帳画面での手動変更不可） |
| hospital_name | TEXT? | かかりつけ病院 |
| microchip_number | TEXT? | マイクロチップ番号 |
| insurance_info | TEXT? | 保険情報 |
| memo | TEXT? | メモ |
| created_at | TEXT NOT NULL | 作成日時 |
| updated_at | TEXT NOT NULL | 更新日時 |

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

> **外部キー制約**: `PRAGMA foreign_keys = ON` を設定済み。vaccinations/weight_logsはpets削除時にON DELETE CASCADEで連鎖削除される。

#### マイグレーション履歴
| バージョン | 変更内容 |
|-----------|---------|
| v1→v2 | licenses テーブルに `extra_data TEXT` カラムを追加 |
| v2→v3 | licenses.photo_path / saved_image_path、pets.photo_path をフルパスから相対パスに一括変換 |

### 5.2 SharedPreferences + Keychain

| キー | 保存先 | 用途 |
|------|--------|------|
| ftue_completed | SharedPreferences | 初回チュートリアル完了フラグ |
| total_creation_count | SharedPreferences | 累計作成枚数 |
| kc_total_creation_count | Keychain | 累計作成枚数バックアップ（再インストール復元用） |
| draft_data | SharedPreferences | 作成途中のドラフトデータ（JSON） |
| has_ordered | SharedPreferences | 物理商品の注文ボタン押下フラグ |

> **注**: プレミアム状態はSharedPreferencesに保存せず、`PurchaseManager`（RevenueCat SDK）に一元管理。

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

#### 免許証描画のOS別文字位置補正（設計判断）
`license_painter` の Canvas 描画で、**Android は iOS よりフォントのベースライン位置が高く（文字が上にずれて）見える**フォントメトリクス差がある。
- **方針**: `fontFamily` を明示する根本対応は **iOS 既存ユーザーの免許証の見た目が変わってしまう**ため採らず、**`Platform.isAndroid` 限定で各テキストの Y 座標を下げて補正**する（iOS は v1.1.0 当時のまま不変＝iOS が正）。
- 補正対象（2026-06-16時点）: 氏名・住所・交付・品種・生年月日・優良バッジ・ハンコ「ウチノ子」の漢字・生年月日ひみつ表記「ひ・み・つ」。補正量は実機で確認しながら調整した実測値。
- 縦書きハンコ・ひみつ表記は1文字ずつ描画するため、**漢字/中点だけをピンポイントで補正**できる（カタカナ・平仮名と別管理）。

### 6.3 コンポーネント規約
- **ElevatedButton**: primary色、12px角丸、白文字（一部画面では28px角丸）
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

### 7.3 購入処理の仕様
- `purchasePackage()` の戻り値: `bool?`（`true`=成功、`false`=失敗、`null`=ユーザーキャンセル）
- ユーザーキャンセル時はエラーメッセージを表示しない
- 購入成功時はpop前にScaffoldMessengerの参照を保持してからSnackBar表示（pop後context無効化対策）

### 7.4 コスチューム区分（確定: 無料12種 / プレミアム35種、計47種）

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
| PVCカード | ¥2,280 | クレジットカードサイズ、NFC付き |
| レジンタグ | ¥2,480 | Φ30mm（カン含め32mm）レジン丸型、首輪取り付け可能、NFC付き |
| セット | ¥3,980 | カード + タグ（¥780お得） |

### 8.2 PVCカード製造
- **製造方式**: 自家印刷（Canon PIXUS TS8530）
- **NFC**: NTAG215（504バイト）
- **初期投資**: ¥26,253（プリンタ所有済み、カード/NFC/ラミネート等）
- **原価/枚**: ¥453（材料¥153 + 送料¥150 + 手数料¥150）
- **粗利/枚**: ¥1,527
- **裏面デザイン**: `assets/print_templates/card_back.png`（91.6×60mm @600dpi、塗り足し3mm込み）
  - 構成: タイトル「うちの子免許証」+ 罫線 / NFCアイコン（線画）+ 「NFC」+「スマホをかざしてね」/ 罫線 + ジョーク注意書き
  - 再生成: `assets/print_templates/generate_card_back.py`（Pillow使用、定数で文字サイズ・位置・色を調整可能）
  - 元アイコン素材は `assets/print_templates/nfc_icon.png` に保管（PCクラッシュ時の復元用）

### 8.3 レジンタグ製造
- **製造方式**: ハンドメイド（しゅーとが制作、約25分/個）
- **材料**: 2液性エポキシレジン + プラバン芯材 + NTAG215シール + 防水フィルム
- **サイズ**: Φ30mm（カン含め32mm）/ 高さ6mm / 約8-12g
- **原価/個**: ¥469（材料¥121 + 送料¥150 + 手数料¥198）
- **粗利/個**: ¥1,511
- **裏面デザイン**: `assets/print_templates/tag_back.png`（Φ25mm @1200dpi、円形RGBA PNG・円外は完全透明）
  - 構成: タイトル「うちの子免許証」/ NFCアイコン（線画）+「NFC」+「スマホをかざしてね」（注意書きはサイズ的に省略、表面と販売ページでカバー）
  - 再生成: `assets/print_templates/generate_tag_back.py`（Pillow使用、円形マスクで切り抜き）
  - レジン越しに見えるためカードより高解像度（1200dpi）で出力
  - 印刷直径25mm = プラバン芯材サイズ（塗り足しなし、円形PNGがそのまま切り抜きガイド）

### 8.4 注文フロー

> **刷新設計（v1.1.2・実装済み／本番Webhook稼働開始 2026-06-21）**: 以下は「アプリ内完結方式」。
> 本番Webhookインフラは稼働開始し、Closed Test内部テスト版で**本番E2E検証済み**（→「本番Webhook構成と検証」参照）。
> ただし**製品版（一般公開）への投入はClosed Test 14日完走後**のため、一般ユーザーの現行運用は当面「アプリ内Stripe決済 + 別途Googleフォーム写真送付」方式（git `b884a04` 時点、運用手順は `order_flow.md` / git履歴参照）が継続する。

#### 刷新の目的（なぜ変えるか）
- 現行は決済とGoogleフォームが独立した別チャネルで、フォームが決済前でも単独送信できる。
  結果、実測で**約70%が決済せずフォーム送信のみで終わる**離脱が発生（収益損失）。
- 未決済者からは住所・連絡先も取得できず「幽霊注文」化する。
- → **決済を唯一の入口にし、写真送付をアプリ内で完結**させて外部フォーム/メールへの離脱をなくす。

#### 全体フロー（アプリ内完結方式）

```
①注文内容を組み立てる（アプリ）
   免許証選択 / タグ・セットは丸形画像作成 / NFC代行チェック
   送信前にサムネ確認「この写真で作ります」
     ↓ 「お支払いに進む」= 受付番号を発番し注文をローカル一時保存
②Stripe決済（外部・住所/メアド必須収集）
   Payment Link URL に client_reference_id=受付番号 を付与
     ↓ 決済成功時のみリダイレクト（session_id付き）
   着地ページ（uchinoko-license.com / GitHub Pages）
   「お支払い完了。二重に払う必要はありません。下のボタンで写真を送信」
     ↓ ボタンを"タップ"してアプリ復帰（ユニバーサルリンク/App Links）
③写真アップロード（アプリ）
   一時保存した注文を読み出し→サムネ確認→送信
   Firebase Storage へ自動アップロード（ユーザーは写真選び直し不要）
     ↓ 全画像成功後に Firestore へ1回書き込み（all-or-nothing）
④完了画面：チェック＋受付番号＋注文サマリ＋発送目安＋問い合わせ口
     ↓
注文履歴（端末ローカルの控え）
```

#### 技術選定
- **写真・注文メタの受け皿**: Firebase Storage（画像）＋ Firestore（注文メタ）。`firebase_core`/Crashlytics は導入済み。
  Storage は 2024/10 以降 **Blazeプラン必須**（無料枠5GB内で実質¥0、予算アラート設定）。
- **認証**: 匿名認証（書き込みを認証必須化）。**App Check**（Play Integrity / App Attest）で不正アップロード・課金荒らしを防ぐ。**いきなり強制せず計測モードから段階導入**（正規ユーザーを誤って弾かないため）。
  - **2026-06-21時点の状態**: iOS（DeviceCheck）・Android（Play Integrity）とも**登録完了・計測モードで運用中**。AndroidのSHA-256は **Play App Signing のアプリ署名鍵証明書**を使用（Play Console「アプリの署名」ページ＝メニューに無い場合は `.../app/{appId}/app-integrity` にURL直アクセスで取得）。**Enforce（強制）切替は両OS製品版が安定してから**（計測データで正規ユーザーが通っていることを確認後）。
- **Stripe Webhook 1本（Cloud Functions）を使う**。役割は「決済成功（`checkout.session.completed`）を Firestore に記録する」のみ＝決済の真実をサーバー側に持つ。Functions 無料枠（月200万回）内で実質¥0。署名検証必須、受信→検証→Firestore書き込みのみの最小実装。
  - **方針変更（v2→v3、設計レビュー反映）**: サーバーレス完全固持をやめ Webhook 1本を導入。これにより突合・救済・計測が自動化され、その便益が実装コストを上回ると判断。
- **通知は Stripe 標準の決済通知メールを継続**（しゅーとが注文発生を知る手段）。Function はメール送信しない（最小実装）。

#### 決済との接続（実機検証済み）
- Stripe Payment Link の `after_completion` で、**決済成功時のみ**着地ページ（`uchinoko-license.com`/GitHub Pages）へ `?session_id={CHECKOUT_SESSION_ID}` 付きでリダイレクト（検証済み：session_id がURLに乗る）。
- iOSの自動復帰（リダイレクトでのユニバーサルリンク発火）は不安定なため、**必ず着地ページに着地→ユーザーのタップでアプリ復帰**に統一（iOS/Android共通）。**復帰不発に備え、受付番号の手入力でアップロードを再開できるフォールバックを置く**。
- **受付番号を `client_reference_id` でPayment Link URLに付与**しStripe側にも紐づけ（`session_id` と合わせた突合キー）。
- **決済成功は Stripe Webhook が `orders/{受付番号}` に `paid=true` を記録**（決済の真実）。アプリの復帰可否に依存せず決済を捕捉できる。

#### 本番Webhook構成と検証（2026-06-21 本番化完了）
- **関数**: `stripeWebhook`（Cloud Functions 2nd gen / Node.js 20 / リージョン `us-east1` / メモリ256MB）。実装は `functions/index.js`。
- **エンドポイントURL**: `https://us-east1-uchino-ko-license.cloudfunctions.net/stripeWebhook`
- **リッスンイベント**: `checkout.session.completed` の1件のみ。
- **secret（Secret Manager管理・コードに埋めない）**: `STRIPE_SECRET_KEY`（本番 `sk_live_…`）／`STRIPE_WEBHOOK_SECRET`（本番エンドポイントの `whsec_…`）。値を変更したら `firebase deploy --only functions --project uchino-ko-license` で反映。
- **本番E2E検証（2026-06-21・実カード決済）**: Closed Test内部テスト版アプリでセット注文¥3,980を実決済し、以下を全確認。検証後に返金・テストデータ削除済み。
  - Firestore `orders/{受付番号}`: `paid:true`（Webhookが記録）/ `uploaded:true` / `productType:"set"` / `imagePaths` 2件 / `amount:3980`
  - Storage `orders/{uid}/{受付番号}/`: `image_0.png`(カード) / `image_1.png`(タグ)
  - Stripe決済: 配送先・氏名・メアド・金額・`client_reference_id`（受付番号）
  - アプリ: 「お写真未送信」バナー解消
- **運用上の注意**:
  - **返金してもFirestoreの`paid`は`true`のまま**。現Webhookは `checkout.session.completed` のみ処理し、`charge.refunded` 等の返金イベントは未対応。返金時はFirestoreを手動更新する（将来refundイベント対応の余地あり）。
  - App Check は現在**計測モード**（enforce未）。強制モードへ切替後は、実機アプリからのStorage/Firestore書き込みを再検証すること。

#### 管理者の確認・突合先（受付番号をキーに照合）
| 確認する物 | 場所 | URL |
|---|---|---|
| 注文メタ＋決済記録(`paid`) | Firebase Console / Firestore `orders` | https://console.firebase.google.com/project/uchino-ko-license/firestore/databases/-default-/data/~2Forders |
| 写真本体 | Firebase Console / Storage `orders/{uid}/{受付番号}/` | https://console.firebase.google.com/project/uchino-ko-license/storage |
| 配送先・氏名・メアド・金額 | Stripeダッシュボード / 決済（本番） | https://dashboard.stripe.com/payments |
| Webhookエンドポイント設定・配信ログ | Stripeダッシュボード / Webhook | https://dashboard.stripe.com/webhooks |
| 関数のログ・デプロイ状況 | Firebase Console / Functions | https://console.firebase.google.com/project/uchino-ko-license/functions |

#### 注文処理の判断基準（製造する／しないの見分け方）
管理者が注文を捌くときは、**次の2条件を両方満たすものだけを本物の注文として製造**する。
1. **受付番号が `UNK-YYYYMMDD-XXXXXX`（`UNK-`で始まる）**。`UNK-`で始まらないもの（例: `TEST-E2E-001`）はアプリ生成ではない手動テストデータ＝製造対象外。
2. **`paid:true` が付いている**（Webhookが記録）。`paid` フィールドが無い／`false` は未決済＝製造しない（金を払わず写真だけ送った「抜け道」。`paid`×`uploaded` の状態判定は上記の状態判定表を参照）。
- 実務では Firestore `orders` を **`paid == true` でフィルタ**すると本物の注文だけに絞れる。
- ダブルチェックは Stripe決済で `client_reference_id`（受付番号）を検索し、決済の有無を確認する。

#### 個人情報の扱い
- 住所・メアド・氏名・NFC代行の飼い主連絡先は **Stripe側に集約**。Firebaseにはペット写真とメタ（ペット名等）のみ。
  個人情報をクラウドに溜めない設計（審査のプライバシー申告・漏洩リスクを最小化）。しゅーとは Stripe で連絡先・住所を、Firebase で写真・注文内容を見る2画面運用。受付番号で行き来する。

#### Firestore `orders/{受付番号}`（受付番号をドキュメントID・個人情報なし）
```
（Webhookが書く）  paid(bool), sessionId, amount, paidAt
（アプリが書く）    orderNumber, productType(card|tag|set), petNames[],
                  quantity, nfcProxy(bool), note, imagePaths[], uploaded(bool), createdAt
```
- **受付番号を共有キーに、Webhook（決済）とアプリ（写真）が同一ドキュメントを更新**。`paid`/`uploaded` の組み合わせで状態を判定：
  - paid=✅ uploaded=✅ → **完遂**（製造へ）
  - paid=✅ uploaded=❌ → **決済済み・写真未達**（救済対象）
  - paid=❌ uploaded=✅ → 未決済（抜け道・無視）
- Storage: `orders/{匿名uid}/{受付番号}/...`。**他人read禁止・自分のみread/write・画像MIME/サイズ上限**。全画像アップ成功後に1回まとめて Firestore へ書く（all-or-nothing、決定的ファイル名で冪等リトライ）。

#### 主要な設計判断（設計レビュー反映）
- **救済（決済済み・写真未達）**: Webhookが書いた `paid=true uploaded=false` を**サーバー側の記録から検知**できる（しゅーとがStripeのメアドへ催促／アプリ起動時に再開導線）。端末ローカル依存をやめサーバー側を真実とする。
- **計測**: `paid` と `uploaded` から**完遂率を自動算出**（刷新が70%離脱を改善したかを数値で測れる）。
- **写真送信前にサムネ確認**を挟む（誤写真の送付・再制作を防ぐ）。
- **NFC代行の連絡先**: 決済画面の任意入力は機能不全のため不採用。当面しゅーとが +¥500 請求メールで内容確認（アプリは `nfcProxy` フラグのみ送る）。頻度が増えたら +¥500 別SKU化を検討。NFC代行スイッチには料金（+¥500）を明記する。
- **備考欄は廃止（2026-06-16）**: 「ご要望・備考」自由記述欄を注文画面から削除。ラッピングや文字色変更など**実現できない要望を書かせて期待を持たせない**ため。`OrderRecord.note` フィールドは後方互換で残置するが常に null（将来再導入する場合に備える）。
- **注文履歴**: 端末ローカルの控え。問い合わせはメール（完了画面・履歴・着地ページに導線、受付番号を件名に）。
- **法務**: 返金・キャンセル特約（受注生産＝返品不可）、写真の保持期間・削除ポリシーをプライバシーポリシーに明記。
- **ロールバック**: **Remote Config の killスイッチ**で新フローを停止し旧フォーム方式へ戻せるようにする（旧フォームは新フロー安定まで残す）。配信済みアプリは個別に戻せないため、これが実質唯一のロールバック手段。
- **リリース順序（2026-06-21 方針変更：iOS先行）**: 当初は「Android先行」だったが、iOSはGoogle Playの「12人×14日」要件が無く早く出せるため、**新フローはiOS先行で投入**に変更。iOS実機テスト＋本番E2E（実決済）合格を受け、**iOS 1.1.2（新フロー）を2026-06-21にApp Store審査提出**（手動リリース選択）。Androidは引き続き Closed Testing 14日完走→製品版申請→新フロー投入。iOS/Android同時には出さず段階公開（旧フォームは新フロー安定まで残す）。
- **既存ユーザー移行**: 旧フォーム途中状態（決済済み・フォーム未送信）の客を新版で検知し問い合わせへ誘導。DBは上書きアップグレードで実機検証。

#### 決済完了の検知について
- v3では **Stripe Webhook で決済成功を受信し Firestore に記録**するため、決済の有無をサーバー側で確実に判定できる（v2の「自己申告＋手動突合」から改善）。
- これにより「払ったのに写真が来ない」の検知、突合、完遂率の計測がすべて自動化される。

#### セキュリティルール（確定版・2026-06-16 Phase D で確定）

`OrderUploadService` の実装（Storage: `orders/{uid}/{受付番号}/image_n.png`・contentType `image/png`／Firestore: doc ID = 受付番号・`uid` フィールド付き `set(merge:true)`・アプリは read しない）に合わせて確定。Firebase Console に貼る。

**Storage**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /orders/{uid}/{allPaths=**} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 10 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

**Firestore**（2026-06-16 レビュー反映で強化版）
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /orders/{orderNumber} {
      allow read: if false;
      // 新規作成: 自分のuidを名乗り、doc IDと中身の orderNumber が一致すること
      allow create: if request.auth != null
                    && request.resource.data.uid == request.auth.uid
                    && request.resource.data.orderNumber == orderNumber;
      // 更新: 上記に加え、決済の真実フィールド(paid/paidAt/sessionId)は変更禁止
      allow update: if request.auth != null
                    && request.resource.data.uid == request.auth.uid
                    && request.resource.data.orderNumber == orderNumber
                    && !request.resource.data.diff(resource.data)
                          .affectedKeys()
                          .hasAny(['paid', 'paidAt', 'sessionId']);
    }
  }
}
```

**設計判断**:
- 書き込み許可は「**新しく書き込む内容の `uid` が自分のuidと一致**」を基本とする（既存ドキュメントのuidは見ない）。理由＝決済時は **Stripe Webhook が先に** `paid=true` のドキュメントを作る（`uid` を持たない）→ その後アプリが同一ドキュメントを merge 更新するため。既存uid一致を要求すると、この「Webhook先・アプリ後」のケースで弾かれる。
- **強化（レビュー反映）**: create/update を分け、(1) **doc ID ＝ 中身の `orderNumber` 一致**を要求（別注文ドキュメントへの混入防止）、(2) 更新時は **`paid`/`paidAt`/`sessionId`（＝Webが書く決済の真実）の変更を禁止**（受付番号を推測して他人docの決済状態を改ざんする攻撃を封じる）。`amount` はアプリ側も書く（=見積額）ため保護対象から除外（Webhook先行時に同値で衝突しないように）。
- `allow read: if false`（Firestore）= アプリは注文メタを読まない（履歴は端末ローカルDB）。最小権限。
- Webhook（Cloud Functions）は **Admin SDK** でルールをバイパスして `paid` を書く。
- **残る割り切り**: 受付番号を推測できれば他人docの非決済メタ（imagePaths等）は依然上書きできるが、受付番号は暗号論的乱数で推測困難・写真本体は uid 分離で読めない・決済の真実は保護済み、のため被害は限定的。MVP では許容。

#### App Check（不正アップロード対策・2026-06-16 Phase D）
- 不正アップロード・課金荒らし対策に **App Check** を導入（`firebase_app_check`、main で unawaited activate）。
- **段階導入**: いきなり強制(Enforce)せず **計測モード（Console側 Unenforced）から**始める。正規ユーザーを誤って弾く事故を避けるため。データを見て問題なければ後日 Enforce に切り替える。
- プロバイダ: **iOS=DeviceCheck**（iOS11+・最大限の端末互換を優先。App Attest は将来検討）、**Android=Play Integrity**、デバッグビルドは debug プロバイダ。
- iOS DeviceCheck の鍵: Apple Developer の DeviceCheck 秘密鍵(.p8)＋Key ID＋Team ID を Firebase Console に登録。

#### 復帰導線（決済→写真送付）の設計判断（2026-06-16 Phase D）
決済往復後にユーザーをアプリの写真送付へ確実に戻すため、**3層**で担保する。
- **本命＝起動時検知**: アプリ起動時に端末ローカルの pending 注文（写真未送信）を検知し、ホーム最上部にバナーを出す。ディープリンクが不発でも**アプリを開き直すだけで復帰できる**最も確実な層。
- **便利＝ディープリンク**: 着地ページの「アプリでお写真を送る」ボタンからアプリ復帰。
  - **方式はカスタムURLスキーム `mofumofulicense://` を採用**（ユニバーサルリンクは不採用）。理由＝決済後はユーザーが `uchinoko-license.com` を Safari で開いている状態で、**同一ドメインのユニバーサルリンクはiOSで不発になりやすい**（Apple仕様）。カスタムスキームはこの制約がなく、設定も軽い（Apple Developer の Associated Domains・AASA・assetlinks・SHA-256・autoVerify が不要）。未インストール時のストア誘導は着地ページ側で補う。
  - どの注文かは**端末ローカルの pending から特定**する（Stripeのリダイレクトに乗るのは session_id で受付番号ではないため、リンクに注文情報は載せない）。`app_links` で受信、Flutter標準ディープリンクは無効化して二重処理を防ぐ。
- **保険＝注文履歴**: `/order/history` から手動で再開（既存）。
- 着地ページ: `docs/order/complete/index.html`（GitHub Pages / `uchinoko-license.com/order/complete/`）。Stripe Payment Link の `after_completion` をここへリダイレクト設定する。

### 8.5 タグ用丸形画像作成機能（TagDesignScreen）
- アプリ内で証明写真を Φ30mm 丸形にトリミング（30mmプラ板に貼付）
- savedImagePath から photoRect 領域をクロップしてプレビュー表示
- ドラッグ + ピンチで位置・サイズ調整
- 出力: Φ1024px PNG（~1040dpi、高解像度印刷対応）
- **カメラロールに保存**（galパッケージ、アルバム名「うちの子免許証」）+ 共有シート
- 保存完了時に `Navigator.pop(context, true)` で注文画面へ結果返却

---

## 9. NFC機能

### 9.1 書き込み内容（v1.0.5〜）

NDEF メッセージに **URIレコード1本のみ** を書き込む。

**URIレコード**
```
https://uchinoko-license.com/n/#<Base64エンコードされたJSON>
```
- ペット情報を `{"n":petName,"b":breed,"o":ownerName,"t":phone,"r":note}` 形式のJSONにしてBase64エンコード
- フラグメント（`#`）以降に置くことでサーバー側に個人情報が送信されない
- iPhone XS以降ではかざすだけで自動通知が出る → Safariが開く → GitHub Pages（`docs/n/index.html`）がJavaScriptでデコードして表示
- アプリ不要で読み取り可能

### 9.2 読み取り処理（後方互換）

`readTag` は2段階で読み取る：
1. **URIレコード優先**: `uchinoko-license.com/n/` を含むURIレコードを探し、フラグメント部分のBase64をデコードしてペット情報を取得
2. **テキストレコードへフォールバック**: URIレコードがなければテキストレコードを探す（v1.0.4以前で書き込まれたタグの後方互換）

### 9.3 文字数制限（v1.0.5〜）

NTAG215容量内に収めるため、NFC書き込み画面で以下を制限：
- 飼い主名: 20文字
- 電話番号: 15文字
- 特記事項: 50文字（v1.0.4までは60文字）

ペット名・品種は免許証作成画面側の制限（13文字・25文字）に依存するが、書き込み直前に `estimateNdefMessageBytes` でバイト数チェックし、超過時はエラー表示。

### 9.4 制約
- NTAG215: 最大504バイト（実効ペイロード約480バイト）
- リアルタイムバイトカウンター表示
- 書き込みタイムアウト: 30秒
- NDEFメッセージサイズは `estimateNdefMessageBytes()` で事前チェック

### 9.3 消去機能
- 読み取り画面（NfcReadScreen）で内容確認後、「タグの内容を消去」ボタンで消去可能
- 確認ダイアログ → 空NDEFメッセージを書き込みで実質消去
- 消去完了画面を表示

### 9.4 安全装置
- **Completerガードチェック**: タイムアウトとタグ検出が同時に起きてもクラッシュしないよう、全分岐に `completer.isCompleted` チェックを実装
- **キャンセル機能**: NFC待機中・書き込み中の両方でキャンセルボタンを表示。ユーザーがいつでも操作を中断可能

### 9.5 対応状況
- **Android**: 実装済み（nfc_manager + Kotlin 2.x パッチ適用）
- **iOS**: 実装済み（Info.plist + Capabilities設定完了、TAG entitlement + iso14443 polling、実機テストOK）
- **機能**: 書き込み・読み取り・消去の3機能

### 9.6 Android OS自動読み取り動作の判断（2026-06-13）

Android では NFC書き込み完了直後、まだタグが端末に近いと OS が別途タグを検知し「収集された新しいタグ」画面を表示する。iOS にはこの動作がない。

**検討した対応案**:
- A: `AndroidManifest.xml` に Intent Filter追加 → ❌却下
  （知らない人がペットタグかざした時にPlay Storeに飛んでしまい、迷子対策機能として致命的）
- B: 「タグから離してOKを押す」フロー追加（Flutterレベルで NFC セッション保持）
- C: `enableForegroundDispatch` のネイティブ実装

**判断: 修正しない**（リリース最短優先、迷子対策機能としては正常動作）

**理由**:
- 知らない人がペットタグをかざした時、OSがブラウザを開いてペット情報ページを表示する動作は必須
- A の Intent Filter で「うちの子免許証アプリで開く」にすると、アプリ未インストール時に Play Store に飛んでしまい、迷子対策として機能しない
- 書き込み直後のOS自動読み取りは「うっとうしい」程度のUX問題で、書き込み成功の証明としても機能している

**再検討トリガー**: テスターから明確な不満が出る / レビューで指摘される等。

### 9.6 情報ページのアプリ導線

`docs/n/index.html`（NFCタグから飛ぶペット情報ページ）の下部に、App Storeへのダウンロードリンクを設置する。

**設計意図**
- NFCタグ自体をアプリのプロモ媒体として機能させる
- ペット情報を見にきた人（拾った人・飼い主自身）に「自分もこのアプリ使ってみたい」と思わせる導線
- グッズ販売リンクは載せない（売り込み感を避け、まずアプリ体験から入ってもらう）

**配置と挙動**
- ペット情報カードの**外側・下**に配置 → JSが`card`の中身を書き換えてもセクションは消えない
- **エラー時（ペット情報が読めない場合）も表示される**（情報ページに辿り着いた時点でアプリへの興味喚起ができる）
- バッジは Apple公式の日本語版「App Storeで入手」（黒）SVGを使用 → `docs/n/app-store-badge.svg`
- リンクは `target="_blank" rel="noopener"` で新規タブ（元のペット情報ページに戻れるように）

**Android版リリース時の対応**
- Google Playバッジを並べて表示する（OS判定はせず両方並べる方式が無難）

### 9.7 ヘルプ・よくある質問機能（v1.0.6〜）

**目的**
- ユーザーからの問い合わせ削減
- NFC関連トラブル（書き込み・読み取り・反応しないとき）の自己解決導線を提供
- 注文関連の不安解消（流れ・キャンセルポリシー）

**設置場所**
- 設定タブ →「サポート」セクションの先頭（サポートIDより上）
- ユーザーが困った時に最初に目に入る位置

**画面構成（2画面構成）**
- `HelpScreen`（一覧）: カテゴリ別にListTileで項目を並べる
- `HelpDetailScreen`（詳細）: 本文をSelectableTextで表示（長押しコピー対応）

**コンテンツデータ管理**
- `lib/data/help_contents.dart` に `const List<HelpItem>` でハードコード
- カテゴリ + タイトル + 本文（複数行String）を保持
- DBには載せない（更新頻度が低く、アプリアップデートで十分）

**項目構成（v1.0.6時点、計7項目）**
- NFC関連（4項目）: 書き込み方法 / 読み取り方法 / 反応しないとき / 対応機種
- 注文関連（3項目）: 注文方法 / 注文後の流れ / キャンセル

**設計判断**
- カテゴリ「アプリの基本的な使い方」「トラブル対応」は **不採用**
  - 理由: アプリ内チュートリアル/FTUEで代替可能、トラブル対応はメール個別対応の方が誠実
- 「機種固有の話」は最小限に
  - 「スマートフォン」表記を基本とし、iOS固有の挙動だけ「iPhone」と明示
  - Android版リリース時の修正範囲を最小化する設計
- ハッシュタグ的な技術用語（NDEF/URIレコード等）は本文に出さない
  - ユーザーには「v1.0.4以前」「新形式」のような表現も避け、対処手順だけ示す

**Android版リリース時の対応**
- ヘルプの「方法2(かざすだけ読み取り)」はiOS前提の挙動説明（画面上部に通知→ブラウザ）
- Androidでは挙動が異なる可能性があるため、Android実機で検証してヘルプ本文を更新する

---

## 10. 広告設計

### 10.1 AdMob設定
- **iOS App ID**: `ca-app-pub-3721612777407461~2563691647`
- **Android App ID**: `ca-app-pub-3721612777407461~6065078681`
- **バナー広告**: ホーム画面・コレクション画面の下部に表示
- **インタースティシャル広告**: 免許証の交付完了時（プレビュー画面）に全画面表示
- **プレミアムユーザー**: 全広告を非表示
- **app-ads.txt**: `docs/app-ads.txt` に配置（GitHub Pages公開、AdMob認証用）

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
| app-ads.txt | docs/app-ads.txt | AdMob広告認証ファイル |
| CNAME | docs/CNAME | GitHub Pagesカスタムドメイン設定（uchinoko-license.com） |

### 11.2 App Store申請情報
- **年齢レーティング**: 4+
- **カテゴリ**: エンターテインメント
- **App Privacy**: 7データ種別申告済み（トラッキング: デバイスID + 広告データ）
- **審査用メモ**: v2作成済み（Review Notes）

### 11.3 アプリ内免責表示
- 交付完了画面（preview_screen）に「※ この免許証は公的な証明書ではありません」を表示
- App Store説明文にも同様の免責を記載

### 11.4 注意事項
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
| 7 | TestFlight実機テスト（IAP Sandbox含む） | Done |
| 8 | スクリーンショット撮影（8枚） | Done（App Store Connectアップロード済み） |
| 9 | 最終TestFlight + チーム最終レビュー | Done（法務/ASO/技術の3チームレビュー完了） |
| 10 | App Store審査提出 | Done（v1.0.0リリース済み） |

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
| 4 | PVCカード販売 | ¥2,280/枚 | 注文画面実装済み（Stripe本番URL差し替え済み） |
| 5 | レジンタグ販売 | ¥2,480/個 | 注文画面実装済み（Stripe本番URL差し替え済み） |
| 6 | セット販売 | ¥3,980 | 注文画面実装済み（Stripe本番URL差し替え済み） |
| 7 | ペット手帳プレミアム | 未定 | 将来 |

### 14.2 Year 1 収益予測（中間シナリオ）

| 項目 | 金額 |
|------|------|
| 広告収入（DAU 500 × eCPM¥80） | ¥146,000 |
| プレミアム課金（CVR 5%、DL 10,000） | ¥150,000 |
| 物理商品（月20件 × 粗利¥1,500） | ¥360,000 |
| **合計** | **約¥656,000** |

> 販売チャネル戦略・集客施策・課金率改善施策の詳細は `docs/marketing_plan.md` を参照。

---

## 15. 開発進捗サマリー

> 詳細なタスク管理は `HANDOFF.md` も参照。

### 完了済み
- 全画面UI実装（17画面 + editor/サブ）
- 画像合成エンジン（Canvas描画 + 2048px出力、写真回転対応）
- 背景自動削除（ONNX Runtime）
- 課金システム（RevenueCat + ¥300 Lifetime、本番キー差し替え済み、キャンセル時エラー非表示対応）
- 広告（AdMob バナー+インタースティシャル、UMP同意フロー10秒タイムアウト）
- NFC書き込み・読み取り・消去機能（iOS + Android両対応、Completerガード+キャンセルボタン実装）
- 注文システムUI（4画面 + タグ用丸形デザイン）
- 法務ドキュメント（5ページ + app-ads.txt、NFC機能・物理商品対応済み）
- ASO / 審査メモ / App Privacy
- デコ素材（コスチューム47種確定）
- Googleフォーム作成（注文受付用）
- RevenueCat本番キー差し替え
- kDevMode / kUseTestAds リリースビルドガード
- Stripe本番URL差し替え・商品画像追加
- 商品写真撮影＆アプリ内スライドショー組み込み（7枚）
- App Storeスクリーンショット（8枚アップロード済み）
- 申請前チーム最終レビュー（法務/ASO/技術）
- アプリ内免責表示（交付完了画面＋ASO説明文）
- **v1.0.0 App Storeリリース完了**
- v1.0.2: バグ修正9件 + サポートID表示機能追加 + warning全解消
- v1.0.3: 写真回転UX改善（スナップ縮小/デッドゾーン改善/角度表示/haptic）+ 画像パス相対パス化（アプデ後画像消失バグ修正）
- v1.0.4: グッズ価格改定（カード¥2,280 / タグ¥2,480 / セット¥3,980）
- v1.0.5: NFC URIレコード対応（iPhoneでアプリ不要で読み取り可能、URIレコード1本のみ書き込み、読み取りはテキストレコードへフォールバック）+ NFC書き込み画面の文字数制限追加（飼い主名20/電話15/特記50）+ 写真パスバグ修正（PathResolverセルフヒーリング、DBバージョン4マイグレーション、preview_screen保存時相対化）
- v1.0.6: ヘルプ・よくある質問機能追加（設定タブ、2画面構成、計7項目: NFC関連4 + 注文関連3）
- v1.0.7: 注文画面カード画像保存バグ修正（savedImagePath → resolvedSavedImagePath）

### 未完了（リリース後）
- ~~AdMob app-ads.txt認証待ち~~ → 完了（2026-04-07）
- オファーコード作成（友人向けプレミアム無料配布）
- iPad最適化（スクリーンショット・UI対応）
- 物理商品製造ライン構築
