import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ファイルパスの解決ユーティリティ
///
/// iOSではアプリアップデート時にサンドボックスのUUIDが変わるため、
/// DBにフルパスを保存すると無効になる。
/// Androidでは Documents パスに `/Documents/` という文字列が含まれず、
/// `/data/user/0/<package>/app_flutter/` が使われるため、
/// `/Documents/` マーカー方式は使えない。
///
/// このクラスは両OS対応の相対パス↔フルパスの変換を一元管理する。
/// 設計ポイント:
/// - **チェック1（両OS共通）**: `_documentsPath` を直接アンカーとして相対化
/// - **チェック2（iOS のみ）**: `/Documents/` マーカーで旧UUIDパスをセルフヒーリング
/// - **冪等性**: 既に相対パスの場合は何度呼んでも同じ結果
///
/// アプリ起動時に [init] を呼んで初期化すること。
class PathResolver {
  PathResolver._();

  static String? _documentsPath;

  /// Documentsディレクトリのパスを取得（キャッシュ済み）
  static String get documentsPath {
    assert(_documentsPath != null, 'PathResolver.init() を先に呼んでください');
    return _documentsPath!;
  }

  /// 初期化（main.dartで起動時に1回呼ぶ）
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
  }

  /// テスト用：_documentsPath を直接設定
  @visibleForTesting
  // ignore: avoid_setters_without_getters
  static set documentsPathForTest(String? path) {
    _documentsPath = path;
  }

  // ───────────────────────────────────────────────────────
  // resolve: 相対パス or フルパス → フルパス
  // ───────────────────────────────────────────────────────

  /// 相対パスまたはフルパスからフルパスを返す
  ///
  /// - 相対パス → Documentsパスと結合
  /// - フルパス（現Documents配下）→ そのまま
  /// - フルパス（旧UUID等）→ セルフヒーリングで現Documentsに付け替え
  /// - 救済不能の絶対パス → そのまま返す（呼び出し側で File 存在チェック推奨）
  /// - null/empty → null
  static String? resolve(String? path) {
    return _resolveImpl(path, isIOS: Platform.isIOS);
  }

  /// テスト用：iOS フラグを引数で受ける版
  @visibleForTesting
  static String? resolveForTest(String? path, {required bool isIOS}) {
    return _resolveImpl(path, isIOS: isIOS);
  }

  static String? _resolveImpl(String? path, {required bool isIOS}) {
    if (path == null || path.isEmpty) return null;
    final docsPath = _documentsPath;
    if (docsPath == null) return path;

    // 相対パス → Documents パスと結合
    if (!_isAbsolute(path)) {
      return '$docsPath/$path';
    }

    // 既に現Documents配下ならそのまま
    if (path == docsPath || path.startsWith('$docsPath/')) {
      return path;
    }

    // iOS の /private プレフィックス対応
    if (isIOS && path.startsWith('/private$docsPath/')) {
      return path;
    }

    // セルフヒーリング: 旧パスから救済
    final relative = _extractRelativeImpl(path, isIOS: isIOS);
    if (relative != null) {
      return '$docsPath/$relative';
    }

    // 救済不可、そのまま返す
    return path;
  }

  // ───────────────────────────────────────────────────────
  // toRelative: 絶対パス → 相対パス（冪等）
  // ───────────────────────────────────────────────────────

  /// フルパスから相対パス（Documents以降）を抽出する
  ///
  /// - 既に相対パス → そのまま返す（**冪等性**）
  /// - 現Documents配下のフルパス → Documents以降を返す
  /// - iOS のみ: `/Documents/` マーカーで旧UUIDパスを救済
  /// - フォールバック: ファイル名のみ（バグ検出のため debugPrint）
  /// - null/empty → null
  static String? toRelative(String? path) {
    return _toRelativeImpl(path, isIOS: Platform.isIOS);
  }

  /// テスト用：iOS フラグを引数で受ける版
  @visibleForTesting
  static String? toRelativeForTest(String? path, {required bool isIOS}) {
    return _toRelativeImpl(path, isIOS: isIOS);
  }

  static String? _toRelativeImpl(String? path, {required bool isIOS}) {
    if (path == null || path.isEmpty) return null;

    // 既に相対パス → そのまま返す（冪等性）
    if (!_isAbsolute(path)) return path;

    final docsPath = _documentsPath;
    if (docsPath == null) {
      return path.split('/').last;
    }

    final extracted = _extractRelativeImpl(path, isIOS: isIOS);
    if (extracted != null) return extracted;

    // フォールバック: ファイル名のみ（バグ検出のため debugPrint）
    if (kDebugMode) {
      // ignore: avoid_print
      print('[PathResolver] Fallback used (file name only): $path');
    }
    return path.split('/').last;
  }

  /// 絶対パスから相対パス部分を抽出する内部ヘルパ（resolve / toRelative 共通）
  static String? _extractRelativeImpl(String absolute, {required bool isIOS}) {
    final docsPath = _documentsPath;
    if (docsPath == null) return null;

    // チェック1: 現 Documents パスから直接相対化（両OS対応の本命）
    if (absolute.startsWith('$docsPath/')) {
      return absolute.substring(docsPath.length + 1);
    }

    // iOS の /private プレフィックス対応
    if (isIOS && absolute.startsWith('/private$docsPath/')) {
      return absolute.substring('/private$docsPath/'.length);
    }

    // チェック2: iOS マーカー（旧 UUID パス対応、セルフヒーリング）
    if (isIOS) {
      const iosMarker = '/Documents/';
      final idx = absolute.indexOf(iosMarker);
      if (idx != -1) {
        return absolute.substring(idx + iosMarker.length);
      }
    }

    return null;
  }

  static bool _isAbsolute(String path) => path.startsWith('/');
}
