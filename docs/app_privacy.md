# App Privacy（栄養ラベル）申告ガイド

App Store Connectの「App Privacy」セクションで申告する内容。
しゅーとがApp Store Connectで入力する際の参考資料。

## 前提
- アプリにログイン/アカウント機能なし
- 写真はすべてオンデバイス処理（サーバー送信なし）
- カスタムUser ID未使用（RevenueCat/Crashlytics共に匿名ID）

---

## 1. Data Used to Track You（トラッキングに使うデータ）

> 「トラッキング」= 他のアプリやウェブサイトをまたいでユーザーを追跡すること

| データ種別 | Apple分類 | 収集元 | 用途 |
|---|---|---|---|
| Device ID（端末識別子） | Identifiers > Device ID | Google AdMob | Third-Party Advertising |
| Advertising Data（広告データ） | Usage Data > Advertising Data | Google AdMob | Third-Party Advertising |

**なぜトラッキング「あり」なのか**: AdMobはIDFA等のデバイス識別子を使って、他のアプリ/サイトでの行動と紐付けた広告配信を行うため。ATTプロンプト（トラッキング許可ダイアログ）の表示が必須。

---

## 2. Data Linked to You（あなたに紐付くデータ）

**→ なし**

アカウント機能がなく、カスタムUser IDも設定していないため、収集データはユーザー個人に紐付かない。

---

## 3. Data Not Linked to You（あなたに紐付かないデータ）

| データ種別 | Apple分類 | 収集元 | 用途 |
|---|---|---|---|
| Coarse Location（おおまかな位置情報） | Location > Coarse Location | Google AdMob（IPアドレスから都市レベル推定） | Advertising |
| Device ID（端末識別子） | Identifiers > Device ID | AdMob + Firebase Crashlytics (Installation ID) | Advertising, Analytics |
| Advertising Data（広告データ） | Usage Data > Advertising Data | Google AdMob | Advertising |
| Product Interaction（製品操作） | Usage Data > Product Interaction | Google AdMob（アプリ起動、広告視聴等） | Advertising, Analytics |
| Crash Data（クラッシュデータ） | Diagnostics > Crash Data | Firebase Crashlytics + AdMob SDK | Analytics |
| Performance Data（パフォーマンスデータ） | Diagnostics > Performance Data | Firebase Crashlytics + AdMob SDK（デバイス/OS情報） | Analytics |
| Purchase History（購入履歴） | Purchases > Purchase History | RevenueCat | App Functionality, Analytics |

---

## 4. Data Not Collected（収集しないデータ）

以下はすべて「収集しない」を選択：

- Contact Info（連絡先情報: 名前、メール、電話番号等）
- Health & Fitness（健康/フィットネス）
- Financial Info（金融情報: クレジットカード等）
- Precise Location（精密な位置情報: GPS等）
- Sensitive Info（機密情報）
- Contacts（連絡先リスト）
- User Content（ユーザーコンテンツ: 写真※サーバー送信しないため）
- Browsing History（閲覧履歴）
- Search History（検索履歴）
- Identifiers > User ID（ユーザーID ※匿名IDのみ使用）
- Other Data（その他）

---

## App Store Connect入力手順

### Step 1: 「Does your app collect data?」
→ **Yes** を選択

### Step 2: 収集するデータ種別を選択
以下にチェックを入れる：
- [x] Location > Coarse Location
- [x] Purchases > Purchase History
- [x] Usage Data > Product Interaction
- [x] Usage Data > Advertising Data
- [x] Diagnostics > Crash Data
- [x] Diagnostics > Performance Data
- [x] Identifiers > Device ID

### Step 3: 各データの詳細を設定

**Coarse Location:**
- Used for: Third-Party Advertising
- Linked to user: No
- Used for tracking: No（位置情報自体はトラッキング目的ではなく広告表示用）

**Purchase History:**
- Used for: App Functionality, Analytics
- Linked to user: No
- Used for tracking: No

**Product Interaction:**
- Used for: Third-Party Advertising, Analytics
- Linked to user: No
- Used for tracking: No

**Advertising Data:**
- Used for: Third-Party Advertising
- Linked to user: No
- Used for tracking: **Yes**

**Crash Data:**
- Used for: Analytics
- Linked to user: No
- Used for tracking: No

**Performance Data:**
- Used for: Analytics
- Linked to user: No
- Used for tracking: No

**Device ID:**
- Used for: Third-Party Advertising, Analytics
- Linked to user: No
- Used for tracking: **Yes**

---

## ATT（App Tracking Transparency）プロンプト

AdMobを使用するため、iOS 14.5以降でATTプロンプトの表示が必須。
UMP（User Messaging Platform）同意フローで実装済み（ad_manager.dart の `_requestConsent()`）。

### Info.plist に必要なキー
```xml
<key>NSUserTrackingUsageDescription</key>
<string>広告をあなたの興味に合わせて表示するために使用します</string>
```

---

## SDK別データ収集まとめ

### Google AdMob (google_mobile_ads)
- Coarse Location（IPベース）
- Device ID（IDFA等）
- Advertising Data
- Product Interaction
- Crash Data（SDK内部）
- Performance Data

### Firebase Crashlytics (firebase_crashlytics)
- Crash Data（スタックトレース、アプリ状態）
- Performance Data（デバイス/OS情報）
- Device ID（Firebase Installation ID）

### RevenueCat (purchases_flutter)
- Purchase History

### ONNX Runtime (image_background_remover)
- **データ収集なし**（完全オンデバイス処理）
