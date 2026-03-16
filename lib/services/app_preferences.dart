import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'purchase_manager.dart';

/// アプリ全体の設定・状態管理（SharedPreferences + Keychain ラッパー）
///
/// FTUE、累計作成制限、作成フロー一時保存（バックグラウンド殺し対策）を管理する。
/// 課金状態は [PurchaseManager] に一元管理（RevenueCat）。
/// 作成数はKeychainにもバックアップし、再インストール時に復元する。
/// アプリ起動時に [init] を呼んで初期化すること。
class AppPreferences {
  static SharedPreferences? _prefs;
  static const _secureStorage = FlutterSecureStorage();

  // ── キー定数 ──
  static const _keyFtueCompleted = 'ftue_completed';
  static const _keyDraftData = 'draft_data';
  static const _keyTotalCreations = 'total_creation_count';
  static const _keyHasOrdered = 'has_ordered';
  // Keychain用キー（再インストールでも消えない）
  static const _keychainTotalCreations = 'kc_total_creation_count';

  /// アプリ起動時に呼び出す
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Keychainから作成数を復元（再インストール対策）
    await _syncFromKeychain();
  }

  /// Keychainの値がSharedPreferencesより大きければ復元（再インストール検出）
  static Future<void> _syncFromKeychain() async {
    try {
      final keychainStr =
          await _secureStorage.read(key: _keychainTotalCreations);
      final keychainCount = int.tryParse(keychainStr ?? '') ?? 0;
      final localCount = _prefs?.getInt(_keyTotalCreations) ?? 0;

      if (keychainCount > localCount) {
        // 再インストール検出: Keychainの値で上書き
        await _prefs?.setInt(_keyTotalCreations, keychainCount);
        debugPrint(
          'AppPreferences: Restored creation count from Keychain: '
          '$keychainCount (local was $localCount)',
        );
      }
    } catch (e) {
      // Keychainアクセス失敗時はローカル値をそのまま使う
      debugPrint('AppPreferences: Keychain sync error: $e');
    }
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
  // 作成制限（無料ユーザーは累計2枚まで）
  // ─────────────────────────────────────────────

  static const int freeCreationLimit = 2;

  /// プレミアム購入済みか（PurchaseManagerに委譲）
  static bool get isPremium => PurchaseManager.instance.isPremium;

  /// 累計作成数
  static int get totalCreationCount =>
      _prefs?.getInt(_keyTotalCreations) ?? 0;

  /// 残り作成可能数
  static int get remainingCreations {
    if (isPremium) return 99;
    return max(0, freeCreationLimit - totalCreationCount);
  }

  /// 免許証を作成できるか（累計上限チェック）
  static bool get canCreateLicense {
    if (isPremium) return true;
    return totalCreationCount < freeCreationLimit;
  }

  /// 作成数をインクリメント（保存成功時に呼ぶ）
  ///
  /// SharedPreferencesとKeychainの両方に書き込む。
  static Future<void> incrementCreationCount() async {
    final total = (_prefs?.getInt(_keyTotalCreations) ?? 0) + 1;
    await _prefs?.setInt(_keyTotalCreations, total);
    // Keychainにもバックアップ（再インストール対策）
    try {
      await _secureStorage.write(
        key: _keychainTotalCreations,
        value: total.toString(),
      );
    } catch (e) {
      debugPrint('AppPreferences: Keychain write error: $e');
    }
  }

  /// 作成数を直接設定（サーバー同期用）
  static Future<void> setTotalCreationCount(int count) async {
    await _prefs?.setInt(_keyTotalCreations, count);
    try {
      await _secureStorage.write(
        key: _keychainTotalCreations,
        value: count.toString(),
      );
    } catch (e) {
      debugPrint('AppPreferences: Keychain write error: $e');
    }
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

  // ─────────────────────────────────────────────
  // 注文フラグ（商品スライドショーの条件分岐用）
  // ─────────────────────────────────────────────

  /// 注文ボタンを押したことがあるか
  static bool get hasOrdered =>
      _prefs?.getBool(_keyHasOrdered) ?? false;

  /// 注文済みとしてマーク
  static Future<void> setHasOrdered() async {
    await _prefs?.setBool(_keyHasOrdered, true);
  }
}
