import 'package:path_provider/path_provider.dart';

/// ファイルパスの解決ユーティリティ
///
/// iOSではアプリアップデート時にサンドボックスのUUIDが変わるため、
/// DBにフルパスを保存すると無効になる。
/// このクラスは相対パス↔フルパスの変換を一元管理する。
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

  /// 相対パスまたはフルパスからフルパスを返す
  ///
  /// - 相対パス（例: `licenses/license_123.png`）→ Documentsパスと結合
  /// - フルパス（例: `/var/mobile/.../Documents/licenses/license_123.png`）→ そのまま返す
  /// - null → null
  static String? resolve(String? path) {
    if (path == null || path.isEmpty) return null;
    // 既にフルパスならそのまま
    if (path.startsWith('/')) return path;
    // 相対パスならDocumentsパスと結合
    return '$_documentsPath/$path';
  }

  /// フルパスから相対パス（Documents/以降）を抽出する
  ///
  /// - フルパスに `/Documents/` が含まれる場合 → その後ろを返す
  /// - 既に相対パスの場合 → そのまま返す
  /// - null → null
  static String? toRelative(String? path) {
    if (path == null || path.isEmpty) return null;
    // 既に相対パス（/で始まらない）ならそのまま
    if (!path.startsWith('/')) return path;
    // /Documents/ 以降を切り出す
    const marker = '/Documents/';
    final idx = path.indexOf(marker);
    if (idx != -1) {
      return path.substring(idx + marker.length);
    }
    // /Documents/ が見つからない場合（tmpパス等）はファイル名だけ返す
    return path.split('/').last;
  }
}
