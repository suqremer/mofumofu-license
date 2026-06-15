import 'dart:convert';
import 'dart:math';

import '../services/path_resolver.dart';

/// 注文の状態
///
/// - [pending]  決済前にローカル保存した状態（写真はまだ送信していない）。
///              アプリ起動時にこの状態の注文を検知し、写真送付の再開導線を出す。
/// - [uploaded] 写真のアップロードが完了した状態（注文の控え）。
enum OrderStatus {
  pending,
  uploaded;

  static OrderStatus fromName(String? name) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// 物理グッズ注文の端末ローカル記録
///
/// 役割は2つ:
///  1. 「写真未送信の注文（[OrderStatus.pending]）」を検知して救済導線を出すための一時保存。
///  2. 注文完了後の控え（注文履歴画面で表示）。
///
/// 個人情報（住所・メアド・氏名）は持たない。それらは Stripe 側に集約し、
/// この記録とは受付番号（[orderNumber]）で突き合わせる。
class OrderRecord {
  /// 受付番号（UNK-YYYYMMDD-XXXXXX）。ローカル・Firestore・Stripe を結ぶ共通キー。
  final String orderNumber;

  /// 商品種別: 'card' | 'tag' | 'set'
  final String productType;

  /// 対象の免許証のペット名（表示・確認用）
  final List<String> petNames;

  /// 数量（選択した免許証の枚数）
  final int quantity;

  /// NFC書き込み代行の希望
  final bool nfcProxy;

  /// 備考（任意）
  final String? note;

  /// アップロード対象の画像パス（DB保存時は相対パス化する）
  final List<String> imagePaths;

  /// 合計金額（円）
  final int amount;

  /// 状態
  final OrderStatus status;

  /// 決済セッションID（決済から復帰した時に受け取る。未決済なら null）
  final String? sessionId;

  /// 注文（受付番号発番）日時
  final DateTime createdAt;

  const OrderRecord({
    required this.orderNumber,
    required this.productType,
    required this.petNames,
    required this.quantity,
    required this.nfcProxy,
    this.note,
    required this.imagePaths,
    required this.amount,
    this.status = OrderStatus.pending,
    this.sessionId,
    required this.createdAt,
  });

  /// 受付番号に使う文字セット（紛らわしい 0/O・1/I/L を除外、問い合わせ口頭でも伝わるように）
  static const _codeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  /// 受付番号を生成する（例: UNK-20260615-7K2QF9）
  ///
  /// 一意性は決済の session_id が担保するため、これは人間が読む表示・突合用。
  /// 6桁（約11億通り）で日次の衝突をほぼ排除する。
  static String generateOrderNumber([DateTime? now, Random? random]) {
    final t = now ?? DateTime.now();
    final rnd = random ?? Random();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final code = List.generate(
      6,
      (_) => _codeAlphabet[rnd.nextInt(_codeAlphabet.length)],
    ).join();
    return 'UNK-$y$m$d-$code';
  }

  /// DB の Map からモデルを生成
  factory OrderRecord.fromMap(Map<String, dynamic> map) {
    return OrderRecord(
      orderNumber: map['order_number'] as String,
      productType: map['product_type'] as String,
      petNames: _decodeStringList(map['pet_names'] as String?),
      quantity: map['quantity'] as int,
      nfcProxy: (map['nfc_proxy'] as int? ?? 0) == 1,
      note: map['note'] as String?,
      imagePaths: _decodeStringList(map['image_paths'] as String?),
      amount: map['amount'] as int,
      status: OrderStatus.fromName(map['status'] as String?),
      sessionId: map['session_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// モデルを DB の Map に変換
  ///
  /// image_paths は保存時に相対パス化する（iOS の UUID 変動 / Android のパス差異対策。
  /// licenses テーブルと同じ方針）。
  Map<String, dynamic> toMap() {
    return {
      'order_number': orderNumber,
      'product_type': productType,
      'pet_names': jsonEncode(petNames),
      'quantity': quantity,
      'nfc_proxy': nfcProxy ? 1 : 0,
      'note': note,
      'image_paths': jsonEncode(
        imagePaths.map((p) => PathResolver.toRelative(p) ?? p).toList(),
      ),
      'amount': amount,
      'status': status.name,
      'session_id': sessionId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// フルパスに解決された画像パス（File 操作・アップロード用）
  List<String> get resolvedImagePaths =>
      imagePaths.map((p) => PathResolver.resolve(p) ?? p).toList();

  OrderRecord copyWith({
    String? orderNumber,
    String? productType,
    List<String>? petNames,
    int? quantity,
    bool? nfcProxy,
    String? note,
    List<String>? imagePaths,
    int? amount,
    OrderStatus? status,
    String? sessionId,
    DateTime? createdAt,
  }) {
    return OrderRecord(
      orderNumber: orderNumber ?? this.orderNumber,
      productType: productType ?? this.productType,
      petNames: petNames ?? this.petNames,
      quantity: quantity ?? this.quantity,
      nfcProxy: nfcProxy ?? this.nfcProxy,
      note: note ?? this.note,
      imagePaths: imagePaths ?? this.imagePaths,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<String> _decodeStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}
