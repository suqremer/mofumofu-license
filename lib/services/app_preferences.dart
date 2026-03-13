import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/dev_config.dart';

/// アプリ全体の設定・状態管理（SharedPreferences ラッパー）
///
/// FTUE、月間作成制限、作成フロー一時保存（バックグラウンド殺し対策）を管理する。
/// アプリ起動時に [init] を呼んで初期化すること。
class AppPreferences {
  static SharedPreferences? _prefs;

  // ── キー定数 ──
  static const _keyFtueCompleted = 'ftue_completed';
  static const _keyDraftData = 'draft_data';
  static const _keyTotalCreations = 'total_creation_count';
  static const _keyPurchasedProductId = 'purchased_product_id';

  /// アプリ起動時に呼び出す
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─────────────────────────────────────────────
  // FTUE（初回起動体験）
  // ─────────────────────────────────────────────

  /// FTUE が完了済みか
  static bool get isFtueCompleted =>
      _prefs?.getBool(_keyFtueCompleted) ?? false;

  /// FTUE を完了としてマーク
  static Future<void> setFtueCompleted() async {
    await _prefs?.setBool(_keyFtueCompleted, true);
  }

  // ─────────────────────────────────────────────
  // 課金状態
  // ─────────────────────────────────────────────

  /// 購入済み商品IDを取得
  static String? get purchasedProductId =>
      _prefs?.getString(_keyPurchasedProductId);

  /// 購入済み商品IDを保存
  static Future<void> setPurchasedProductId(String productId) async {
    await _prefs?.setString(_keyPurchasedProductId, productId);
  }

  /// プレミアム購入済みか（kDevMode時は常にtrue）
  static bool get isPremium {
    if (kDevMode) return true;
    return purchasedProductId != null;
  }

  // ─────────────────────────────────────────────
  // 作成制限（無料ユーザーは累計2枚まで）
  // ─────────────────────────────────────────────

  static const int freeCreationLimit = 2;

  /// 累計作成数
  static int get totalCreationCount =>
      _prefs?.getInt(_keyTotalCreations) ?? 0;

  /// 残り作成可能数
  static int get remainingCreations {
    if (kDevMode || isPremium) return 99;
    return max(0, freeCreationLimit - totalCreationCount);
  }

  /// 免許証を作成できるか（累計上限チェック）
  static bool get canCreateLicense {
    if (kDevMode || isPremium) return true;
    return totalCreationCount < freeCreationLimit;
  }

  /// 作成数をインクリメント（保存成功時に呼ぶ）
  static Future<void> incrementCreationCount() async {
    final total = _prefs?.getInt(_keyTotalCreations) ?? 0;
    await _prefs?.setInt(_keyTotalCreations, total + 1);
  }

  /// 作成数を直接設定（サーバー同期用：再インストール時にサーバーの値で上書き）
  static Future<void> setTotalCreationCount(int count) async {
    await _prefs?.setInt(_keyTotalCreations, count);
  }

  /// 初回作成かどうか（完成画面のボタン動的切り替え用）
  static bool get isFirstCreation => totalCreationCount == 0;

  // ─────────────────────────────────────────────
  // 作成フロー一時保存（バックグラウンド殺し対策）
  // ─────────────────────────────────────────────

  /// 作成中のデータを保存
  static Future<void> saveDraft(Map<String, dynamic> data) async {
    await _prefs?.setString(_keyDraftData, jsonEncode(data));
  }

  /// 保存済みの作成データを取得（なければ null）
  static Map<String, dynamic>? getDraft() {
    final json = _prefs?.getString(_keyDraftData);
    if (json == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return null;
    }
  }

  /// 作成データを破棄（作成完了 or ユーザーがキャンセル時）
  static Future<void> clearDraft() async {
    await _prefs?.remove(_keyDraftData);
  }

  /// ドラフトが存在するか
  static bool get hasDraft =>
      _prefs?.getString(_keyDraftData) != null;
}
