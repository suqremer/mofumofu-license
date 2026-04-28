import 'package:flutter_test/flutter_test.dart';
import 'package:mofumofu_license/services/path_resolver.dart';

void main() {
  // ────────────────────────────────────────
  // Android パターンのテスト
  // ────────────────────────────────────────
  group('PathResolver.toRelative (Android)', () {
    setUp(() {
      PathResolver.documentsPathForTest =
          '/data/user/0/com.example.app/app_flutter';
    });

    tearDown(() {
      PathResolver.documentsPathForTest = null;
    });

    test('既に相対パス → 冪等にそのまま返す', () {
      expect(
        PathResolver.toRelativeForTest('photos/foo.png', isIOS: false),
        'photos/foo.png',
      );
    });

    test('Android Documents配下のフルパス → サブディレクトリを保持して相対化', () {
      const path = '/data/user/0/com.example.app/app_flutter/photos/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: false),
        'photos/foo.png',
      );
    });

    test('Android: 多階層サブディレクトリも正しく相対化', () {
      const path =
          '/data/user/0/com.example.app/app_flutter/licenses/2026/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: false),
        'licenses/2026/foo.png',
      );
    });

    test('Android: Android で /Documents/ マーカーは効かない（誤マッチ防止）', () {
      // ユーザーストレージに /Documents/ が偶然含まれるケース
      const path = '/storage/emulated/0/Documents/foo.png';
      // Android では iOS マーカーは無視されるのでファイル名フォールバック
      expect(
        PathResolver.toRelativeForTest(path, isIOS: false),
        'foo.png',
      );
    });

    test('Android: 不明な絶対パス → ファイル名フォールバック', () {
      const path = '/somewhere/else/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: false),
        'foo.png',
      );
    });

    test('null → null', () {
      expect(PathResolver.toRelativeForTest(null, isIOS: false), null);
    });

    test('empty → null', () {
      expect(PathResolver.toRelativeForTest('', isIOS: false), null);
    });
  });

  // ────────────────────────────────────────
  // iOS パターンのテスト
  // ────────────────────────────────────────
  group('PathResolver.toRelative (iOS)', () {
    setUp(() {
      PathResolver.documentsPathForTest =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents';
    });

    tearDown(() {
      PathResolver.documentsPathForTest = null;
    });

    test('既に相対パス → 冪等', () {
      expect(
        PathResolver.toRelativeForTest('photos/foo.png', isIOS: true),
        'photos/foo.png',
      );
    });

    test('iOS Documents配下のフルパス → 相対化', () {
      const path =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: true),
        'photos/foo.png',
      );
    });

    test('iOS 旧UUIDパス → /Documents/ マーカーでセルフヒーリング', () {
      const path =
          '/var/mobile/Containers/Data/Application/UUID-OLD/Documents/photos/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: true),
        'photos/foo.png',
      );
    });

    test('iOS /private プレフィックス対応', () {
      const path =
          '/private/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: true),
        'photos/foo.png',
      );
    });

    test('iOS: /Documents/ を含まない不明な絶対パス → ファイル名フォールバック', () {
      const path = '/somewhere/else/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: true),
        'foo.png',
      );
    });

    test('iOS: extra_data 内の旧パス（多階層）でも救済可能', () {
      const path =
          '/var/mobile/Containers/Data/Application/UUID-OLD/Documents/licenses/2026/foo.png';
      expect(
        PathResolver.toRelativeForTest(path, isIOS: true),
        'licenses/2026/foo.png',
      );
    });
  });

  // ────────────────────────────────────────
  // 冪等性テスト（複数回呼んでも壊れない）
  // ────────────────────────────────────────
  group('PathResolver.toRelative 冪等性', () {
    test('Android: 2回呼んでも同じ結果（ダブル相対化バグ防止）', () {
      PathResolver.documentsPathForTest =
          '/data/user/0/com.example.app/app_flutter';
      const path = '/data/user/0/com.example.app/app_flutter/photos/foo.png';
      final once = PathResolver.toRelativeForTest(path, isIOS: false);
      final twice = PathResolver.toRelativeForTest(once, isIOS: false);
      expect(once, twice);
      expect(once, 'photos/foo.png');
    });

    test('iOS: 2回呼んでも同じ結果', () {
      PathResolver.documentsPathForTest =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents';
      const path =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png';
      final once = PathResolver.toRelativeForTest(path, isIOS: true);
      final twice = PathResolver.toRelativeForTest(once, isIOS: true);
      expect(once, twice);
      expect(once, 'photos/foo.png');
    });

    test('Android: 3回呼んでも同じ', () {
      PathResolver.documentsPathForTest =
          '/data/user/0/com.example.app/app_flutter';
      const path = '/data/user/0/com.example.app/app_flutter/licenses/foo.png';
      final once = PathResolver.toRelativeForTest(path, isIOS: false);
      final twice = PathResolver.toRelativeForTest(once, isIOS: false);
      final thrice = PathResolver.toRelativeForTest(twice, isIOS: false);
      expect(once, thrice);
      expect(once, 'licenses/foo.png');
    });
  });

  // ────────────────────────────────────────
  // resolve のテスト
  // ────────────────────────────────────────
  group('PathResolver.resolve (Android)', () {
    setUp(() {
      PathResolver.documentsPathForTest =
          '/data/user/0/com.example.app/app_flutter';
    });

    tearDown(() {
      PathResolver.documentsPathForTest = null;
    });

    test('null → null', () {
      expect(PathResolver.resolveForTest(null, isIOS: false), null);
    });

    test('empty → null', () {
      expect(PathResolver.resolveForTest('', isIOS: false), null);
    });

    test('相対パス → Documents結合', () {
      expect(
        PathResolver.resolveForTest('photos/foo.png', isIOS: false),
        '/data/user/0/com.example.app/app_flutter/photos/foo.png',
      );
    });

    test('現Documents配下のフルパス → そのまま', () {
      const path = '/data/user/0/com.example.app/app_flutter/photos/foo.png';
      expect(PathResolver.resolveForTest(path, isIOS: false), path);
    });

    test('Android で iOS マーカーは効かず、そのまま返す（救済不可）', () {
      const path = '/storage/emulated/0/Documents/photos/foo.png';
      expect(PathResolver.resolveForTest(path, isIOS: false), path);
    });
  });

  group('PathResolver.resolve (iOS)', () {
    setUp(() {
      PathResolver.documentsPathForTest =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents';
    });

    tearDown(() {
      PathResolver.documentsPathForTest = null;
    });

    test('現Documents配下のフルパス → そのまま', () {
      const path =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png';
      expect(PathResolver.resolveForTest(path, isIOS: true), path);
    });

    test('旧UUIDのフルパス → 現Documentsに付け替え（セルフヒーリング）', () {
      const oldPath =
          '/var/mobile/Containers/Data/Application/UUID-OLD/Documents/photos/foo.png';
      const expected =
          '/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png';
      expect(PathResolver.resolveForTest(oldPath, isIOS: true), expected);
    });

    test('/private プレフィックス → そのまま（OSが解決する）', () {
      const path =
          '/private/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png';
      expect(PathResolver.resolveForTest(path, isIOS: true), path);
    });

    test('相対パス → Documents結合', () {
      expect(
        PathResolver.resolveForTest('photos/foo.png', isIOS: true),
        '/var/mobile/Containers/Data/Application/UUID-NEW/Documents/photos/foo.png',
      );
    });
  });
}
