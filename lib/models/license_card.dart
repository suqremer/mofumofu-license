import 'dart:convert';

import '../services/path_resolver.dart';

/// 免許証データモデル
class LicenseCard {
  final int? id;
  final String petName;
  final String species; // 犬, 猫, うさぎ, ハムスター, 鳥, その他
  final String? breed; // 品種（任意）
  final DateTime? birthDate; // 生年月日（任意）
  final String? gender; // ♂, ♀, 不明（任意）
  final String? specialty; // 特技（任意）
  final String licenseType; // にゃん転免許, わん転免許 等
  final String photoPath; // トリミング済み写真のパス
  final String costumeId; // コスチュームフレームのID
  final String frameColor; // ゴールド, シルバー 等
  final String templateType; // japan, usa
  final String? savedImagePath; // 完成画像のパス
  final Map<String, dynamic>? extraData; // コスチューム配置・写真調整等のJSON
  final DateTime createdAt;
  final DateTime updatedAt;

  const LicenseCard({
    this.id,
    required this.petName,
    required this.species,
    this.breed,
    this.birthDate,
    this.gender,
    this.specialty,
    required this.licenseType,
    required this.photoPath,
    this.costumeId = 'gakuran',
    this.frameColor = 'gold',
    this.templateType = 'japan',
    this.savedImagePath,
    this.extraData,
    required this.createdAt,
    required this.updatedAt,
  });

  /// DBのMapからモデルを生成
  factory LicenseCard.fromMap(Map<String, dynamic> map) {
    return LicenseCard(
      id: map['id'] as int?,
      petName: map['pet_name'] as String,
      species: map['species'] as String,
      breed: map['breed'] as String?,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      gender: map['gender'] as String?,
      specialty: map['specialty'] as String?,
      licenseType: map['license_type'] as String,
      photoPath: map['photo_path'] as String,
      costumeId: map['costume_id'] as String? ?? 'gakuran',
      frameColor: map['frame_color'] as String? ?? 'gold',
      templateType: map['template_type'] as String? ?? 'japan',
      savedImagePath: map['saved_image_path'] as String?,
      extraData: map['extra_data'] != null
          ? jsonDecode(map['extra_data'] as String) as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// モデルをDBのMapに変換
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pet_name': petName,
      'species': species,
      'breed': breed,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'specialty': specialty,
      'license_type': licenseType,
      'photo_path': photoPath,
      'costume_id': costumeId,
      'frame_color': frameColor,
      'template_type': templateType,
      'saved_image_path': savedImagePath,
      'extra_data': extraData != null ? jsonEncode(extraData) : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// フルパスに解決された写真パス（File操作用）
  String get resolvedPhotoPath => PathResolver.resolve(photoPath) ?? photoPath;

  /// フルパスに解決された完成画像パス（File操作用）
  String? get resolvedSavedImagePath => PathResolver.resolve(savedImagePath);

  /// コピーして一部を変更した新しいインスタンスを返す
  LicenseCard copyWith({
    int? id,
    String? petName,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    String? specialty,
    String? licenseType,
    String? photoPath,
    String? costumeId,
    String? frameColor,
    String? templateType,
    String? savedImagePath,
    Map<String, dynamic>? extraData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LicenseCard(
      id: id ?? this.id,
      petName: petName ?? this.petName,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      specialty: specialty ?? this.specialty,
      licenseType: licenseType ?? this.licenseType,
      photoPath: photoPath ?? this.photoPath,
      costumeId: costumeId ?? this.costumeId,
      frameColor: frameColor ?? this.frameColor,
      templateType: templateType ?? this.templateType,
      savedImagePath: savedImagePath ?? this.savedImagePath,
      extraData: extraData ?? this.extraData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
