import 'dart:io';

/// RevenueCat + アプリ内課金の設定
///
/// RevenueCatダッシュボードで取得したAPI Keyと、
/// ストアに登録する商品IDを管理する。
class IapConfig {
  IapConfig._();

  // ─────────────────────────────────────────────
  // RevenueCat API Keys
  // ─────────────────────────────────────────────

  static const String _appleApiKey = 'appl_devqORajcICbBWJDTuWHZFRfxZW';
  // TODO: Google Play対応時にRevenueCatダッシュボードで取得したキーに差し替える
  static const String _googleApiKey = 'goog_XXXXXXXXXXXXXXXXXX';

  /// 現在のプラットフォームに応じたAPIキーを返す
  static String get apiKey {
    if (Platform.isIOS || Platform.isMacOS) return _appleApiKey;
    return _googleApiKey;
  }

  // ─────────────────────────────────────────────
  // 商品・Entitlement 設定
  // ─────────────────────────────────────────────

  /// RevenueCatのEntitlement ID（ダッシュボードで設定）
  static const String premiumEntitlementId = 'Uchino Ko License Pro';

  /// プレミアム商品ID（App Store / Google Play に登録する商品IDと一致させる）
  static const String premiumProductId = 'mofumofu_premium';

  // ─────────────────────────────────────────────
  // Subscriber Attributes キー
  // ─────────────────────────────────────────────

  /// 累計作成数（再インストール対策：サーバー側で管理）
  static const String attrTotalCreations = 'total_creations';
}
