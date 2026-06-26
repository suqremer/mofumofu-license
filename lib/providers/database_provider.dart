import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/license_card.dart';
import '../models/pet.dart';
import '../models/order_record.dart';

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

/// 写真未送信（pending）注文のプロバイダ。
/// 注文作成・写真送信完了・削除のたびに ref.invalidate(pendingOrdersProvider) で
/// 更新する。ホーム画面の未送信バナーがこれを watch して自動で最新になる。
final pendingOrdersProvider = FutureProvider<List<OrderRecord>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getPendingOrders();
});
