import 'package:flutter_test/flutter_test.dart';
import 'package:mofumofu_license/models/pet.dart';

void main() {
  group('Pet', () {
    final now = DateTime(2026, 3, 3, 12, 0, 0);
    final birthDate = DateTime(2021, 8, 20);

    /// 全フィールドを持つテスト用Map
    Map<String, dynamic> fullMap() => {
          'id': 1,
          'name': 'たま',
          'species': '猫',
          'breed': 'スコティッシュフォールド',
          'birth_date': birthDate.toIso8601String(),
          'gender': '♀',
          'photo_path': '/photos/tama.jpg',
          'hospital_name': 'もふもふ動物病院',
          'microchip_number': '392141234567890',
          'insurance_info': 'もふもふ保険 プランA',
          'memo': 'おやつ大好き',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

    /// 必須フィールドだけのテスト用Map
    Map<String, dynamic> requiredOnlyMap() => {
          'name': 'ポチ',
          'species': '犬',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

    group('fromMap', () {
      test('全フィールドが正しくパースされる', () {
        final pet = Pet.fromMap(fullMap());

        expect(pet.id, 1);
        expect(pet.name, 'たま');
        expect(pet.species, '猫');
        expect(pet.breed, 'スコティッシュフォールド');
        expect(pet.birthDate, birthDate);
        expect(pet.gender, '♀');
        expect(pet.photoPath, '/photos/tama.jpg');
        expect(pet.hospitalName, 'もふもふ動物病院');
        expect(pet.microchipNumber, '392141234567890');
        expect(pet.insuranceInfo, 'もふもふ保険 プランA');
        expect(pet.memo, 'おやつ大好き');
        expect(pet.createdAt, now);
        expect(pet.updatedAt, now);
      });

      test('必須フィールドだけでパースできる', () {
        final pet = Pet.fromMap(requiredOnlyMap());

        expect(pet.id, isNull);
        expect(pet.name, 'ポチ');
        expect(pet.species, '犬');
        expect(pet.breed, isNull);
        expect(pet.birthDate, isNull);
        expect(pet.gender, isNull);
        expect(pet.photoPath, isNull);
        expect(pet.hospitalName, isNull);
        expect(pet.microchipNumber, isNull);
        expect(pet.insuranceInfo, isNull);
        expect(pet.memo, isNull);
      });
    });

    group('toMap', () {
      test('全フィールドが正しいMapに変換される', () {
        final pet = Pet.fromMap(fullMap());
        final map = pet.toMap();

        expect(map['id'], 1);
        expect(map['name'], 'たま');
        expect(map['species'], '猫');
        expect(map['breed'], 'スコティッシュフォールド');
        expect(map['birth_date'], birthDate.toIso8601String());
        expect(map['gender'], '♀');
        expect(map['photo_path'], '/photos/tama.jpg');
        expect(map['hospital_name'], 'もふもふ動物病院');
        expect(map['microchip_number'], '392141234567890');
        expect(map['insurance_info'], 'もふもふ保険 プランA');
        expect(map['memo'], 'おやつ大好き');
        expect(map['created_at'], now.toIso8601String());
        expect(map['updated_at'], now.toIso8601String());
      });

      test('idがnullの場合はMapに含まれない', () {
        final pet = Pet.fromMap(requiredOnlyMap());
        final map = pet.toMap();

        expect(map.containsKey('id'), isFalse);
      });
    });

    group('fromMap -> toMap ラウンドトリップ', () {
      test('全フィールド有りでラウンドトリップが一致する', () {
        final original = fullMap();
        final pet = Pet.fromMap(original);
        final roundTripped = pet.toMap();

        expect(roundTripped['id'], original['id']);
        expect(roundTripped['name'], original['name']);
        expect(roundTripped['species'], original['species']);
        expect(roundTripped['breed'], original['breed']);
        expect(roundTripped['birth_date'], original['birth_date']);
        expect(roundTripped['gender'], original['gender']);
        expect(roundTripped['photo_path'], original['photo_path']);
        expect(roundTripped['hospital_name'], original['hospital_name']);
        expect(roundTripped['microchip_number'], original['microchip_number']);
        expect(roundTripped['insurance_info'], original['insurance_info']);
        expect(roundTripped['memo'], original['memo']);
        expect(roundTripped['created_at'], original['created_at']);
        expect(roundTripped['updated_at'], original['updated_at']);
      });

      test('必須フィールドだけでラウンドトリップが一致する', () {
        final original = requiredOnlyMap();
        final pet = Pet.fromMap(original);
        final roundTripped = pet.toMap();

        expect(roundTripped['name'], original['name']);
        expect(roundTripped['species'], original['species']);
        expect(roundTripped['created_at'], original['created_at']);
        expect(roundTripped['updated_at'], original['updated_at']);
      });
    });

    group('copyWith', () {
      test('一部フィールドだけ変更した新しいインスタンスを返す', () {
        final pet = Pet.fromMap(fullMap());
        final copied = pet.copyWith(name: 'みけ', species: '猫');

        expect(copied.name, 'みけ');
        expect(copied.species, '猫');
        // 変更していないフィールドは元のまま
        expect(copied.id, pet.id);
        expect(copied.breed, pet.breed);
        expect(copied.hospitalName, pet.hospitalName);
        expect(copied.memo, pet.memo);
      });

      test('元のインスタンスは変更されない', () {
        final pet = Pet.fromMap(fullMap());
        pet.copyWith(name: 'みけ');

        expect(pet.name, 'たま');
      });

      test('全フィールドを変更できる', () {
        final pet = Pet.fromMap(requiredOnlyMap());
        final newDate = DateTime(2026, 4, 1);
        final copied = pet.copyWith(
          id: 99,
          name: '変更後',
          species: 'うさぎ',
          breed: 'ネザーランドドワーフ',
          birthDate: newDate,
          gender: '♂',
          photoPath: '/photos/new.jpg',
          hospitalName: '新しい病院',
          microchipNumber: '999999999999999',
          insuranceInfo: '新しい保険',
          memo: '新しいメモ',
          createdAt: newDate,
          updatedAt: newDate,
        );

        expect(copied.id, 99);
        expect(copied.name, '変更後');
        expect(copied.species, 'うさぎ');
        expect(copied.breed, 'ネザーランドドワーフ');
        expect(copied.birthDate, newDate);
        expect(copied.gender, '♂');
        expect(copied.photoPath, '/photos/new.jpg');
        expect(copied.hospitalName, '新しい病院');
        expect(copied.microchipNumber, '999999999999999');
        expect(copied.insuranceInfo, '新しい保険');
        expect(copied.memo, '新しいメモ');
        expect(copied.createdAt, newDate);
        expect(copied.updatedAt, newDate);
      });
    });
  });
}
