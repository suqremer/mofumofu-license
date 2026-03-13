import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mofumofu_license/models/license_template.dart';

void main() {
  group('FrameColor', () {
    group('all', () {
      test('全フレーム色は6件ある', () {
        expect(FrameColor.all.length, 6);
      });
    });

    group('freeOnly', () {
      test('無料フレーム色は3件ある', () {
        expect(FrameColor.freeOnly.length, 3);
      });

      test('全て無料である', () {
        for (final fc in FrameColor.freeOnly) {
          expect(fc.isPremium, isFalse);
        }
      });
    });

    group('findById', () {
      test('goldでゴールドが返る', () {
        final fc = FrameColor.findById('gold');

        expect(fc.id, 'gold');
        expect(fc.label, 'ゴールド');
        expect(fc.isPremium, isFalse);
      });

      test('silverでシルバーが返る', () {
        final fc = FrameColor.findById('silver');

        expect(fc.id, 'silver');
        expect(fc.label, 'シルバー');
      });

      test('rose_goldでローズゴールド（プレミアム）が返る', () {
        final fc = FrameColor.findById('rose_gold');

        expect(fc.id, 'rose_gold');
        expect(fc.label, 'ローズゴールド');
        expect(fc.isPremium, isTrue);
      });

      test('存在しないIDではデフォルト(gold)が返る', () {
        final fc = FrameColor.findById('nonexistent');

        expect(fc.id, 'gold');
        expect(fc.label, 'ゴールド');
      });
    });
  });

  group('LicenseType', () {
    group('all', () {
      test('全免許種別は5件ある', () {
        expect(LicenseType.all.length, 5);
      });
    });

    group('freeOnly', () {
      test('無料免許種別は3件ある', () {
        expect(LicenseType.freeOnly.length, 3);
      });

      test('全て無料である', () {
        for (final lt in LicenseType.freeOnly) {
          expect(lt.isPremium, isFalse);
        }
      });
    });

    group('forSpecies', () {
      test('猫で猫用 + 全種用が返る', () {
        final types = LicenseType.forSpecies('猫');
        final ids = types.map((t) => t.id).toList();

        // 猫専用
        expect(ids, contains('nyanten'));
        // 全種共通
        expect(ids, contains('mofumofu'));
        expect(ids, contains('kokusai'));
        expect(ids, contains('gold_menky'));
        // 犬専用は含まれない
        expect(ids, isNot(contains('wanten')));
      });

      test('犬で犬用 + 全種用が返る', () {
        final types = LicenseType.forSpecies('犬');
        final ids = types.map((t) => t.id).toList();

        // 犬専用
        expect(ids, contains('wanten'));
        // 全種共通
        expect(ids, contains('mofumofu'));
        // 猫専用は含まれない
        expect(ids, isNot(contains('nyanten')));
      });

      test('うさぎでは全種共通のみ返る', () {
        final types = LicenseType.forSpecies('うさぎ');
        final ids = types.map((t) => t.id).toList();

        expect(ids, contains('mofumofu'));
        expect(ids, contains('kokusai'));
        expect(ids, contains('gold_menky'));
        expect(ids, isNot(contains('nyanten')));
        expect(ids, isNot(contains('wanten')));
      });
    });

    group('findById', () {
      test('nyanten でにゃん転免許が返る', () {
        final lt = LicenseType.findById('nyanten');

        expect(lt.id, 'nyanten');
        expect(lt.label, 'にゃん転免許');
        expect(lt.targetSpecies, '猫');
      });

      test('kokusai でうちの子国際免許（プレミアム）が返る', () {
        final lt = LicenseType.findById('kokusai');

        expect(lt.id, 'kokusai');
        expect(lt.label, 'うちの子国際免許');
        expect(lt.isPremium, isTrue);
      });

      test('存在しないIDではデフォルト(mofumofu)が返る', () {
        final lt = LicenseType.findById('nonexistent');

        expect(lt.id, 'mofumofu');
        expect(lt.label, 'うちの子免許');
      });
    });
  });

  group('TemplateType', () {
    group('fromId', () {
      test('japanで日本風が返る', () {
        final tt = TemplateType.fromId('japan');

        expect(tt, TemplateType.japan);
        expect(tt.id, 'japan');
        expect(tt.label, '日本風');
      });

      test('usaで海外風が返る', () {
        final tt = TemplateType.fromId('usa');

        expect(tt, TemplateType.usa);
        expect(tt.id, 'usa');
        expect(tt.label, '海外風');
      });

      test('存在しないIDではデフォルト(japan)が返る', () {
        final tt = TemplateType.fromId('nonexistent');

        expect(tt, TemplateType.japan);
      });
    });
  });

  group('LicenseTemplate', () {
    group('japan', () {
      test('出力サイズが1024x646である', () {
        expect(LicenseTemplate.japan.outputSize, const Size(1024, 646));
      });

      test('テンプレートタイプがjapanである', () {
        expect(LicenseTemplate.japan.type, TemplateType.japan);
      });

      test('発行元テキストが正しい', () {
        expect(LicenseTemplate.japan.issuerText, 'うちの子免許センター');
      });

      test('ヘッダーテキストが正しい', () {
        expect(LicenseTemplate.japan.headerText, 'うちの子公安委員会');
      });
    });

    group('usa', () {
      test('出力サイズが1024x646である', () {
        expect(LicenseTemplate.usa.outputSize, const Size(1024, 646));
      });

      test('テンプレートタイプがusaである', () {
        expect(LicenseTemplate.usa.type, TemplateType.usa);
      });

      test('発行元テキストが英語である', () {
        expect(LicenseTemplate.usa.issuerText, 'MOFUMOFU LICENSE CENTER');
      });

      test('ヘッダーテキストが英語である', () {
        expect(LicenseTemplate.usa.headerText, 'STATE OF MOFUMOFU');
      });
    });

    group('fromType', () {
      test('TemplateType.japanからjapanテンプレートが取得できる', () {
        final template = LicenseTemplate.fromType(TemplateType.japan);

        expect(template.type, TemplateType.japan);
        expect(template.outputSize, const Size(1024, 646));
      });

      test('TemplateType.usaからusaテンプレートが取得できる', () {
        final template = LicenseTemplate.fromType(TemplateType.usa);

        expect(template.type, TemplateType.usa);
        expect(template.outputSize, const Size(1024, 646));
      });
    });

    group('fromId', () {
      test('文字列IDからテンプレートを取得できる', () {
        final japan = LicenseTemplate.fromId('japan');
        expect(japan.type, TemplateType.japan);

        final usa = LicenseTemplate.fromId('usa');
        expect(usa.type, TemplateType.usa);
      });
    });

    group('photoRect', () {
      test('japanのphotoRectが実ピクセルに変換される', () {
        final rect = LicenseTemplate.japan.photoRect;

        // photoRectRatio: Rect.fromLTWH(0.62, 0.28, 0.30, 0.50)
        // outputSize: 1024 x 646
        expect(rect.left, closeTo(0.62 * 1024, 0.01));
        expect(rect.top, closeTo(0.28 * 646, 0.01));
        expect(rect.width, closeTo(0.30 * 1024, 0.01));
        expect(rect.height, closeTo(0.50 * 646, 0.01));
      });

      test('usaのphotoRectが実ピクセルに変換される', () {
        final rect = LicenseTemplate.usa.photoRect;

        // photoRectRatio: Rect.fromLTWH(0.05, 0.30, 0.28, 0.50)
        // outputSize: 1024 x 646
        expect(rect.left, closeTo(0.05 * 1024, 0.01));
        expect(rect.top, closeTo(0.30 * 646, 0.01));
        expect(rect.width, closeTo(0.28 * 1024, 0.01));
        expect(rect.height, closeTo(0.50 * 646, 0.01));
      });
    });
  });
}
