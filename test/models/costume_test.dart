import 'package:flutter_test/flutter_test.dart';
import 'package:mofumofu_license/models/costume.dart';

void main() {
  group('Costume', () {
    group('all', () {
      test('全コスチュームは8件ある', () {
        expect(Costume.all.length, 8);
      });
    });

    group('freeOnly', () {
      test('無料コスチュームは5件ある', () {
        expect(Costume.freeOnly.length, 5);
      });

      test('全て無料カテゴリである', () {
        for (final costume in Costume.freeOnly) {
          expect(costume.isFree, isTrue);
          expect(costume.isPremium, isFalse);
        }
      });
    });

    group('premiumOnly', () {
      test('プレミアムコスチュームは3件ある', () {
        expect(Costume.premiumOnly.length, 3);
      });

      test('全てプレミアムカテゴリである', () {
        for (final costume in Costume.premiumOnly) {
          expect(costume.isPremium, isTrue);
          expect(costume.isFree, isFalse);
        }
      });
    });

    group('findById', () {
      test('gakuranで学ランが返る', () {
        final costume = Costume.findById('gakuran');

        expect(costume.id, 'gakuran');
        expect(costume.name, '学ラン');
        expect(costume.category, CostumeCategory.free);
        expect(costume.assetPath, 'assets/costumes/gakuran.png');
        expect(costume.thumbnailPath, 'assets/costumes/thumb_gakuran.png');
      });

      test('sailorでセーラー服が返る', () {
        final costume = Costume.findById('sailor');

        expect(costume.id, 'sailor');
        expect(costume.name, 'セーラー服');
      });

      test('kimonoで着物（プレミアム）が返る', () {
        final costume = Costume.findById('kimono');

        expect(costume.id, 'kimono');
        expect(costume.name, '着物');
        expect(costume.isPremium, isTrue);
      });

      test('存在しないIDではデフォルト(gakuran)が返る', () {
        final costume = Costume.findById('nonexistent_id');

        expect(costume.id, 'gakuran');
        expect(costume.name, '学ラン');
      });

      test('空文字のIDではデフォルト(gakuran)が返る', () {
        final costume = Costume.findById('');

        expect(costume.id, 'gakuran');
      });
    });

    group('sortOrder', () {
      test('無料コスチュームのsortOrderは0-4', () {
        final free = Costume.freeOnly;
        for (int i = 0; i < free.length; i++) {
          expect(free[i].sortOrder, i);
        }
      });

      test('プレミアムコスチュームのsortOrderは10以上', () {
        for (final costume in Costume.premiumOnly) {
          expect(costume.sortOrder, greaterThanOrEqualTo(10));
        }
      });
    });
  });
}
