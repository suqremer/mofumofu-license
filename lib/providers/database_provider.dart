import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/license_card.dart';
import '../models/pet.dart';

/// DBサービスのプロバイダ（アプリ全体で1つのインスタンスを共有）
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// 免許証一覧のプロバイダ
final licensesProvider = FutureProvider<List<LicenseCard>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllLicenses();
});

/// ペット一覧のプロバイダ
final petsProvider = FutureProvider<List<Pet>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllPets();
});

/// 免許証作成数のプロバイダ
final licenseCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getLicenseCount();
});

/// 特定ペットのワクチン記録プロバイダ（petIdをパラメータとして受け取る）
final vaccinationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, petId) async {
  final db = ref.watch(databaseProvider);
  return db.getVaccinationsForPet(petId);
});

/// 特定ペットの体重ログプロバイダ（petIdをパラメータとして受け取る）
final weightLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, petId) async {
  final db = ref.watch(databaseProvider);
  return db.getWeightLogsForPet(petId);
});
