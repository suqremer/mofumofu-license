import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/dev_config.dart';
import '../config/iap_config.dart';
import 'app_preferences.dart';

/// RevenueCat を使ったアプリ内課金管理シングルトン
///
/// アプリ起動時に [initialize] を呼ぶこと。
/// 購入状態は RevenueCat サーバー側で管理される（再インストール対策）。
class PurchaseManager {
  PurchaseManager._();
  static final PurchaseManager instance = PurchaseManager._();

  /// 購入処理中かどうか
  final ValueNotifier<bool> isPurchasing = ValueNotifier(false);

  /// 購入状態の変更通知（UIリビルド用）
  final ValueNotifier<bool> premiumActive = ValueNotifier(false);

  /// 現在のOffering（Paywall表示用）
  Offering? _currentOffering;
  Offering? get currentOffering => _currentOffering;

  // ─────────────────────────────────────────────
  // 初期化
  // ─────────────────────────────────────────────

  /// RevenueCat SDK初期化 + 購入状態復元
  Future<void> initialize() async {
    if (kDevMode) {
      premiumActive.value = true;
      return;
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(IapConfig.apiKey),
      );

      // 購入状態を確認
      await _refreshCustomerInfo();

      // Offeringsを取得（Paywall表示用）
      await _loadOfferings();

      // サーバーの作成数をローカルと同期
      await _syncCreationCount();

      debugPrint('RevenueCat: Initialized');
    } catch (e) {
      debugPrint('RevenueCat: Init error: $e');
    }
  }

  /// Offeringsを取得
  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      _currentOffering = offerings.current;
      debugPrint(
        'RevenueCat: Offering loaded: ${_currentOffering?.identifier ?? "none"}',
      );
    } catch (e) {
      debugPrint('RevenueCat: Offerings error: $e');
    }
  }

  /// CustomerInfoから購入状態を更新
  Future<void> _refreshCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _updatePremiumStatus(info);
    } catch (e) {
      debugPrint('RevenueCat: CustomerInfo error: $e');
    }
  }

  /// Entitlementからプレミアム状態を判定
  void _updatePremiumStatus(CustomerInfo info) {
    final entitlement = info.entitlements.all[IapConfig.premiumEntitlementId];
    premiumActive.value = entitlement?.isActive ?? false;
    debugPrint('RevenueCat: Premium active: ${premiumActive.value}');
  }

  // ─────────────────────────────────────────────
  // 購入
  // ─────────────────────────────────────────────

  /// Packageを購入する（Paywall から呼ぶ）
  Future<bool> purchasePackage(Package package) async {
    isPurchasing.value = true;
    try {
      final info = await Purchases.purchasePackage(package);
      _updatePremiumStatus(info);
      isPurchasing.value = false;
      return isPremium;
    } on PurchasesErrorCode catch (e) {
      debugPrint('RevenueCat: Purchase error: $e');
      isPurchasing.value = false;
      return false;
    } catch (e) {
      debugPrint('RevenueCat: Purchase error: $e');
      isPurchasing.value = false;
      return false;
    }
  }

  /// 過去の購入を復元する（「購入を復元」ボタン用）
  Future<bool> restorePurchases() async {
    isPurchasing.value = true;
    try {
      final info = await Purchases.restorePurchases();
      _updatePremiumStatus(info);
      isPurchasing.value = false;

      // 復元時にサーバーの作成数も同期
      await _syncCreationCount();

      return isPremium;
    } catch (e) {
      debugPrint('RevenueCat: Restore error: $e');
      isPurchasing.value = false;
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // 作成数管理（Subscriber Attributes）
  // ─────────────────────────────────────────────

  /// 作成数をインクリメントしてサーバーに保存
  ///
  /// ローカル（AppPreferences）とサーバー（RevenueCat）の両方を更新する。
  Future<void> incrementCreationCount() async {
    // ローカルを先に更新（オフライン対応）
    await AppPreferences.incrementCreationCount();

    // サーバーにも反映
    final count = AppPreferences.totalCreationCount;
    try {
      await Purchases.setAttributes({
        IapConfig.attrTotalCreations: count.toString(),
      });
      debugPrint('RevenueCat: Updated total_creations=$count');
    } catch (e) {
      debugPrint('RevenueCat: Attribute update error: $e');
      // サーバー更新失敗してもローカルは更新済み → 次回起動時に同期される
    }
  }

  /// サーバーの作成数とローカルを同期
  ///
  /// 再インストール時: サーバーの値 > ローカル(0) → サーバーの値で上書き
  /// 通常時: ローカルの値 >= サーバーの値 → サーバーを更新
  Future<void> _syncCreationCount() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final serverCountStr =
          info.subscriberAttributes[IapConfig.attrTotalCreations]?.value;
      final serverCount = int.tryParse(serverCountStr ?? '') ?? 0;
      final localCount = AppPreferences.totalCreationCount;

      if (serverCount > localCount) {
        // 再インストール検出: サーバーの値で上書き
        await AppPreferences.setTotalCreationCount(serverCount);
        debugPrint(
          'RevenueCat: Synced creation count from server: $serverCount (local was $localCount)',
        );
      } else if (localCount > serverCount) {
        // ローカルが進んでる: サーバーを更新
        await Purchases.setAttributes({
          IapConfig.attrTotalCreations: localCount.toString(),
        });
        debugPrint(
          'RevenueCat: Synced creation count to server: $localCount (server was $serverCount)',
        );
      }
    } catch (e) {
      debugPrint('RevenueCat: Sync creation count error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 状態確認
  // ─────────────────────────────────────────────

  /// プレミアム購入済みか
  bool get isPremium {
    if (kDevMode) return true;
    return premiumActive.value;
  }

  /// リソース解放
  void dispose() {
    isPurchasing.dispose();
    premiumActive.dispose();
  }
}
