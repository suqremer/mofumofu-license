import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/license_card.dart';
import '../models/pet.dart';

/// アプリのローカルDB管理
class DatabaseService {
  static Database? _database;
  static const _dbName = 'mofumofu.db';
  static const _dbVersion = 4;

  /// DBインスタンスを取得（初回は自動作成）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// マイグレーション
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE licenses ADD COLUMN extra_data TEXT');
    }
    // v3 / v4 のパス相対化マイグレーションは iOS の `/Documents/` マーカー
    // 方式に依存しているため、iOS でのみ実行する。
    // Android では PathResolver の改修により、既存のフルパスデータが
    // あっても resolve() がセルフヒーリングするため、マイグレーション不要。
    if (Platform.isIOS) {
      if (oldVersion < 3) {
        await _migratePathsToRelative(db);
      }
      if (oldVersion < 4) {
        await _migratePathsToRelative(db);
        await _migrateExtraDataPaths(db);
      }
    }
  }

  /// extra_data JSON 内の originalPhotoPath を相対パスに変換
  Future<void> _migrateExtraDataPaths(Database db) async {
    const marker = '/Documents/';
    final licenses = await db.query('licenses', columns: ['id', 'extra_data']);

    for (final row in licenses) {
      final extraStr = row['extra_data'] as String?;
      if (extraStr == null || extraStr.isEmpty) continue;

      try {
        final extra = jsonDecode(extraStr) as Map<String, dynamic>;
        final origPath = extra['originalPhotoPath'] as String?;
        if (origPath == null || !origPath.contains(marker)) continue;

        // 相対パスに変換
        extra['originalPhotoPath'] =
            origPath.substring(origPath.indexOf(marker) + marker.length);

        await db.update(
          'licenses',
          {'extra_data': jsonEncode(extra)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        // JSON解析失敗時はスキップ（マイグレーション全体を止めない）
        debugPrint('extra_data migration error for id=${row['id']}: $e');
      }
    }
  }

  /// DBに保存されたフルパスを相対パス（Documents/以降）に変換する
  Future<void> _migratePathsToRelative(Database db) async {
    const marker = '/Documents/';

    // licenses.saved_image_path
    final licenses = await db.query('licenses',
        columns: ['id', 'saved_image_path', 'photo_path']);
    for (final row in licenses) {
      final updates = <String, dynamic>{};

      final savedPath = row['saved_image_path'] as String?;
      if (savedPath != null && savedPath.contains(marker)) {
        updates['saved_image_path'] =
            savedPath.substring(savedPath.indexOf(marker) + marker.length);
      }

      final photoPath = row['photo_path'] as String?;
      if (photoPath != null && photoPath.contains(marker)) {
        updates['photo_path'] =
            photoPath.substring(photoPath.indexOf(marker) + marker.length);
      }

      if (updates.isNotEmpty) {
        await db.update('licenses', updates,
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }

    // pets.photo_path
    final pets = await db.query('pets', columns: ['id', 'photo_path']);
    for (final row in pets) {
      final photoPath = row['photo_path'] as String?;
      if (photoPath != null && photoPath.contains(marker)) {
        final relative =
            photoPath.substring(photoPath.indexOf(marker) + marker.length);
        await db.update('pets', {'photo_path': relative},
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  /// テーブル作成
  Future<void> _onCreate(Database db, int version) async {
    // 免許証テーブル
    await db.execute('''
      CREATE TABLE licenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT,
        birth_date TEXT,
        gender TEXT,
        specialty TEXT,
        license_type TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        costume_id TEXT NOT NULL DEFAULT 'gakuran',
        frame_color TEXT NOT NULL DEFAULT 'gold',
        template_type TEXT NOT NULL DEFAULT 'japan',
        saved_image_path TEXT,
        extra_data TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ペット手帳テーブル
    await db.execute('''
      CREATE TABLE pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT,
        birth_date TEXT,
        gender TEXT,
        photo_path TEXT,
        hospital_name TEXT,
        microchip_number TEXT,
        insurance_info TEXT,
        memo TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ワクチン記録テーブル
    await db.execute('''
      CREATE TABLE vaccinations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        vaccine_name TEXT NOT NULL,
        date TEXT NOT NULL,
        next_date TEXT,
        memo TEXT,
        FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE
      )
    ''');

    // 体重ログテーブル
    await db.execute('''
      CREATE TABLE weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        weight REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE
      )
    ''');
  }

  // === 免許証 CRUD ===

  Future<int> insertLicense(LicenseCard card) async {
    final db = await database;
    return db.insert('licenses', card.toMap());
  }

  Future<List<LicenseCard>> getAllLicenses() async {
    final db = await database;
    final maps = await db.query('licenses', orderBy: 'created_at DESC');
    return maps.map((m) => LicenseCard.fromMap(m)).toList();
  }

  Future<LicenseCard?> getLicense(int id) async {
    final db = await database;
    final maps = await db.query('licenses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return LicenseCard.fromMap(maps.first);
  }

  Future<int> updateLicense(LicenseCard card) async {
    final db = await database;
    return db.update(
      'licenses',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteLicense(int id) async {
    final db = await database;
    return db.delete('licenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getLicenseCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM licenses');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // === ペット CRUD ===

  Future<int> insertPet(Pet pet) async {
    final db = await database;
    return db.insert('pets', pet.toMap());
  }

  Future<Pet?> findPetByNameAndSpecies(String name, String species) async {
    final db = await database;
    final maps = await db.query('pets',
        where: 'name = ? AND species = ?', whereArgs: [name, species], limit: 1);
    if (maps.isEmpty) return null;
    return Pet.fromMap(maps.first);
  }

  Future<List<Pet>> getAllPets() async {
    final db = await database;
    final maps = await db.query('pets', orderBy: 'created_at DESC');
    return maps.map((m) => Pet.fromMap(m)).toList();
  }

  Future<int> updatePet(Pet pet) async {
    final db = await database;
    return db.update('pets', pet.toMap(), where: 'id = ?', whereArgs: [pet.id]);
  }

  /// ペット名変更時に、旧名の免許証も新名に一括更新
  Future<int> updateLicensePetName(String oldName, String newName) async {
    final db = await database;
    return db.update(
      'licenses',
      {'pet_name': newName},
      where: 'pet_name = ?',
      whereArgs: [oldName],
    );
  }

  Future<int> deletePet(int id) async {
    final db = await database;
    return db.delete('pets', where: 'id = ?', whereArgs: [id]);
  }

  // === ワクチン記録 CRUD ===

  Future<int> insertVaccination(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('vaccinations', data);
  }

  Future<List<Map<String, dynamic>>> getVaccinationsForPet(int petId) async {
    final db = await database;
    return db.query(
      'vaccinations',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
  }

  Future<int> updateVaccination(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('vaccinations', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteVaccination(int id) async {
    final db = await database;
    return db.delete('vaccinations', where: 'id = ?', whereArgs: [id]);
  }

  // === 体重ログ CRUD ===

  Future<int> insertWeightLog(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('weight_logs', data);
  }

  Future<List<Map<String, dynamic>>> getWeightLogsForPet(int petId) async {
    final db = await database;
    return db.query(
      'weight_logs',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
  }

  Future<int> deleteWeightLog(int id) async {
    final db = await database;
    return db.delete('weight_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// 全データを削除（設定画面の「データを全て削除」用）
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('weight_logs');
    await db.delete('vaccinations');
    await db.delete('licenses');
    await db.delete('pets');
  }
}
