# App Store Review Notes

## App Overview
"Uchi no Ko Menkyo-sho" (うちの子免許証) is an entertainment app that lets users create fun, illustrated pet ID cards using their pets' photos. The cards use a playful, cartoon-style layout loosely inspired by the format of ID cards, but are clearly designed as novelty pet cards — NOT imitations of any real government-issued documents.

Every generated card includes:
- Pet-specific fields (species, breed, favorite food, etc.) that have no real-world equivalent
- No government seals, holograms, or official markings of any kind

## Demo Steps
1. Launch the app → Home screen shows "Create License" button
2. Tap "Create License" → Select a pet photo from the photo library (or take a new one)
3. Enter pet information (name, species, breed, birthday, favorite food — all fun/fictional data)
4. Choose a frame color (Gold, Silver, Blue, etc.)
5. Optionally add a costume overlay and adjust the photo (crop, background removal)
6. Preview the completed card → Save to camera roll or share via SNS
7. Free users can create up to 2 cards. After reaching the limit, a prompt to purchase Premium is shown.

## Test Account
No login or account is required. The app works entirely offline after download.

## In-App Purchase
- **Product ID**: `mofumofu_premium`
- **Type**: Non-consumable (one-time purchase, ¥300)
- **What it unlocks**:
  - Unlimited card creation (free tier: 2 cards lifetime)
  - Ad removal
  - All costume overlays
  - All frame colors
- **IAP SDK**: RevenueCat (purchases_flutter)
- **Restore Purchases**: A "Restore Purchases" button is available on the Premium purchase screen and in the Settings screen, allowing users to restore previous purchases on new devices.

## Free Tier Limitations
- Users can create up to 2 cards for free (lifetime limit).
- After creating 2 cards, the "Create" flow shows a prompt explaining the limit has been reached and offers the Premium upgrade.
- All basic frame colors and features are available for the first 2 cards. Premium-only costumes display a lock icon.

## Permissions Used
| Permission | Purpose | Dialog Message (Japanese) |
|---|---|---|
| Photo Library (NSPhotoLibraryUsageDescription) | Select pet photos for the card | ペットの写真を選択するために使用します |
| Camera (NSCameraUsageDescription) | Take new pet photos directly in the app | ペットの写真を撮影するために使用します |
| Photo Library Add (NSPhotoLibraryAddUsageDescription) | Save completed cards to the camera roll | 作成したカードを保存するために使用します |
| App Tracking Transparency (NSUserTrackingUsageDescription) | Request permission for personalized ads (AdMob) | 最適な広告を表示するために使用します |

## Third-Party SDKs
| SDK | Purpose | Data Collected |
|---|---|---|
| RevenueCat | In-app purchase management | Purchase history (anonymous) |
| Google AdMob | Banner and interstitial ads (removed for premium users) | Device identifiers for ad targeting (with ATT consent) |
| Firebase Crashlytics | Crash reporting | Crash logs, device model, OS version (no personal data) |
| ONNX Runtime (via image_background_remover) | On-device AI background removal | None (fully on-device) |

## Privacy & Data Handling
- **No user accounts**: No registration, login, or personal data collection.
- **On-device processing**: Photo editing and AI background removal run entirely on-device. No images are uploaded to any server.
- **ATT Compliance**: The app displays the App Tracking Transparency prompt before initializing personalized ads. If the user declines, only non-personalized ads are shown.
- **Privacy Policy**: https://suqremer.github.io/mofumofu-license/privacy-policy/
- **No data shared with third parties** beyond what is disclosed above (AdMob, Crashlytics).

## Important Disclaimers
- The generated cards are NOT real documents and cannot be used as identification.
- A disclaimer is displayed within the app: "このカードはジョーク用です。公的な証明書ではありません。" (This card is for fun. It is not an official certificate.)
- The card design intentionally avoids any resemblance to real government documents:
  - No government seals, logos, or official markings
  - No hologram effects
  - No barcodes or machine-readable elements
  - Fields are pet-specific (species, breed, favorite food) with no real-world equivalent
- The app and its output are clearly entertainment/novelty products for pet owners.

## Content Rating
- The app contains no objectionable content.
- Advertisements are shown to free-tier users (disclosed in Age Rating questionnaire as "Frequent/Intense: Third-Party Advertising").
- The app is NOT submitted to the Kids Category.
- Recommended age rating: 4+ (with ads disclosure).

## Support
- Email: uchino.ko.license@gmail.com
- Support page: https://suqremer.github.io/mofumofu-license/
- Privacy Policy: https://suqremer.github.io/mofumofu-license/privacy-policy/
