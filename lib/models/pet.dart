import '../services/path_resolver.dart';

/// ペット手帳データモデル
class Pet {
  final int? id;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final String? gender;
  final String? photoPath;
  final String? hospitalName;
  final String? microchipNumber;
  final String? insuranceInfo;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Pet({
    this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.gender,
    this.photoPath,
    this.hospitalName,
    this.microchipNumber,
    this.insuranceInfo,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  /// フルパスに解決されたペット写真パス（File操作用）
  String? get resolvedPhotoPath => PathResolver.resolve(photoPath);

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] as int?,
      name: map['name'] as String,
      species: map['species'] as String,
      breed: map['breed'] as String?,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      gender: map['gender'] as String?,
      photoPath: map['photo_path'] as String?,
      hospitalName: map['hospital_name'] as String?,
      microchipNumber: map['microchip_number'] as String?,
      insuranceInfo: map['insurance_info'] as String?,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// モデルをDBのMapに変換
  ///
  /// photoPath は DB 保存時に必ず相対パス化する
  /// （iOS の UUID 変動 / Android の Documents パス差異対策）。
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'photo_path': PathResolver.toRelative(photoPath),
      'hospital_name': hospitalName,
      'microchip_number': microchipNumber,
      'insurance_info': insuranceInfo,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Pet copyWith({
    int? id,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    String? photoPath,
    String? hospitalName,
    String? microchipNumber,
    String? insuranceInfo,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      photoPath: photoPath ?? this.photoPath,
      hospitalName: hospitalName ?? this.hospitalName,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      insuranceInfo: insuranceInfo ?? this.insuranceInfo,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
