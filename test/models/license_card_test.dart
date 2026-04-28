import 'package:flutter_test/flutter_test.dart';
import 'package:mofumofu_license/models/license_card.dart';

void main() {
  group('LicenseCard', () {
    final now = DateTime(2026, 3, 3, 12, 0, 0);
    final birthDate = DateTime(2020, 5, 15);

    /// 全フィールドを持つテスト用Map
    Map<String, dynamic> fullMap() => {
          'id': 1,
          'pet_name': 'たま',
          'species': '猫',
          'breed': 'スコティッシュフォールド',
          'birth_date': birthDate.toIso8601String(),
          'gender': '♀',
          'specialty': 'ごろごろ',
          'license_type': 'にゃん転免許',
          'photo_path': 'photos/tama.jpg',
          'costume_id': 'sailor',
          'frame_color': 'silver',
          'template_type': 'usa',
          'saved_image_path': 'saved/tama_license.png',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

    /// 必須フィールドだけのテスト用Map
    Map<String, dynamic> requiredOnlyMap() => {
          'pet_name': 'ポチ',
          'species': '犬',
          'license_type': 'わん転免許',
          'photo_path': 'photos/pochi.jpg',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

    group('fromMap', () {
      test('全フィールドが正しくパースされる', () {
        final card = LicenseCard.fromMap(fullMap());

        expect(card.id, 1);
        expect(card.petName, 'たま');
        expect(card.species, '猫');
        expect(card.breed, 'スコティッシュフォールド');
        expect(card.birthDate, birthDate);
        expect(card.gender, '♀');
        expect(card.specialty, 'ごろごろ');
        expect(card.licenseType, 'にゃん転免許');
        expect(card.photoPath, 'photos/tama.jpg');
        expect(card.costumeId, 'sailor');
        expect(card.frameColor, 'silver');
        expect(card.templateType, 'usa');
        expect(card.savedImagePath, 'saved/tama_license.png');
        expect(card.createdAt, now);
        expect(card.updatedAt, now);
      });

      test('必須フィールドだけでパースできる', () {
        final card = LicenseCard.fromMap(requiredOnlyMap());

        expect(card.id, isNull);
        expect(card.petName, 'ポチ');
        expect(card.species, '犬');
        expect(card.breed, isNull);
        expect(card.birthDate, isNull);
        expect(card.gender, isNull);
        expect(card.specialty, isNull);
        expect(card.licenseType, 'わん転免許');
        expect(card.photoPath, 'photos/pochi.jpg');
        // デフォルト値の確認
        expect(card.costumeId, 'gakuran');
        expect(card.frameColor, 'gold');
        expect(card.templateType, 'japan');
        expect(card.savedImagePath, isNull);
      });

      test('任意フィールドがnullでも問題ない', () {
        final map = requiredOnlyMap()
          ..['breed'] = null
          ..['birth_date'] = null
          ..['gender'] = null
          ..['specialty'] = null
          ..['saved_image_path'] = null;

        final card = LicenseCard.fromMap(map);

        expect(card.breed, isNull);
        expect(card.birthDate, isNull);
        expect(card.gender, isNull);
        expect(card.specialty, isNull);
        expect(card.savedImagePath, isNull);
      });
    });

    group('toMap', () {
      test('全フィールドが正しいMapに変換される', () {
        final card = LicenseCard.fromMap(fullMap());
        final map = card.toMap();

        expect(map['id'], 1);
        expect(map['pet_name'], 'たま');
        expect(map['species'], '猫');
        expect(map['breed'], 'スコティッシュフォールド');
        expect(map['birth_date'], birthDate.toIso8601String());
        expect(map['gender'], '♀');
        expect(map['specialty'], 'ごろごろ');
        expect(map['license_type'], 'にゃん転免許');
        expect(map['photo_path'], 'photos/tama.jpg');
        expect(map['costume_id'], 'sailor');
        expect(map['frame_color'], 'silver');
        expect(map['template_type'], 'usa');
        expect(map['saved_image_path'], 'saved/tama_license.png');
        expect(map['created_at'], now.toIso8601String());
        expect(map['updated_at'], now.toIso8601String());
      });

      test('idがnullの場合はMapに含まれない', () {
        final card = LicenseCard.fromMap(requiredOnlyMap());
        final map = card.toMap();

        expect(map.containsKey('id'), isFalse);
      });

      test('fromMap -> toMap のラウンドトリップが一致する', () {
        final original = fullMap();
        final card = LicenseCard.fromMap(original);
        final roundTripped = card.toMap();

        expect(roundTripped['id'], original['id']);
        expect(roundTripped['pet_name'], original['pet_name']);
        expect(roundTripped['species'], original['species']);
        expect(roundTripped['breed'], original['breed']);
        expect(roundTripped['birth_date'], original['birth_date']);
        expect(roundTripped['gender'], original['gender']);
        expect(roundTripped['specialty'], original['specialty']);
        expect(roundTripped['license_type'], original['license_type']);
        expect(roundTripped['photo_path'], original['photo_path']);
        expect(roundTripped['costume_id'], original['costume_id']);
        expect(roundTripped['frame_color'], original['frame_color']);
        expect(roundTripped['template_type'], original['template_type']);
        expect(roundTripped['saved_image_path'], original['saved_image_path']);
        expect(roundTripped['created_at'], original['created_at']);
        expect(roundTripped['updated_at'], original['updated_at']);
      });
    });

    group('copyWith', () {
      test('一部フィールドだけ変更した新しいインスタンスを返す', () {
        final card = LicenseCard.fromMap(fullMap());
        final copied = card.copyWith(petName: 'みけ', species: '猫');

        expect(copied.petName, 'みけ');
        expect(copied.species, '猫');
        // 変更していないフィールドは元のまま
        expect(copied.id, card.id);
        expect(copied.breed, card.breed);
        expect(copied.licenseType, card.licenseType);
        expect(copied.photoPath, card.photoPath);
        expect(copied.costumeId, card.costumeId);
        expect(copied.frameColor, card.frameColor);
      });

      test('元のインスタンスは変更されない', () {
        final card = LicenseCard.fromMap(fullMap());
        card.copyWith(petName: 'みけ');

        expect(card.petName, 'たま');
      });

      test('全フィールドを変更できる', () {
        final card = LicenseCard.fromMap(requiredOnlyMap());
        final newDate = DateTime(2026, 4, 1);
        final copied = card.copyWith(
          id: 99,
          petName: '変更後',
          species: 'うさぎ',
          breed: 'ネザーランドドワーフ',
          birthDate: newDate,
          gender: '♂',
          specialty: 'ジャンプ',
          licenseType: 'うちの子免許',
          photoPath: 'photos/new.jpg',
          costumeId: 'kimono',
          frameColor: 'black',
          templateType: 'usa',
          savedImagePath: 'saved/new.png',
          createdAt: newDate,
          updatedAt: newDate,
        );

        expect(copied.id, 99);
        expect(copied.petName, '変更後');
        expect(copied.species, 'うさぎ');
        expect(copied.breed, 'ネザーランドドワーフ');
        expect(copied.birthDate, newDate);
        expect(copied.gender, '♂');
        expect(copied.specialty, 'ジャンプ');
        expect(copied.licenseType, 'うちの子免許');
        expect(copied.photoPath, 'photos/new.jpg');
        expect(copied.costumeId, 'kimono');
        expect(copied.frameColor, 'black');
        expect(copied.templateType, 'usa');
        expect(copied.savedImagePath, 'saved/new.png');
        expect(copied.createdAt, newDate);
        expect(copied.updatedAt, newDate);
      });
    });
  });
}
