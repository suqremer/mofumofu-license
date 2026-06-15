import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/order_record.dart';

/// 注文の写真アップロードと注文記録（Firebase）を扱うサービス。
///
/// 役割分担（設計v3）:
///  - 写真本体     → Firebase Storage（`orders/{uid}/{受付番号}/image_n.png`）
///  - 注文メタ情報 → Firestore（`orders/{受付番号}`、個人情報は持たない）
///  - 決済の真実   → Stripe Webhook（Cloud Functions）が同じドキュメントに `paid` を書く
///
/// 個人情報（住所・メアド・氏名）は Stripe 側にあり、ここには保存しない。
class OrderUploadService {
  OrderUploadService._();
  static final OrderUploadService instance = OrderUploadService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 匿名認証を確実にして uid を返す。
  ///
  /// 既にサインイン済みなら即座に返る。決済前（「お支払いに進む」押下時）に
  /// 呼んで「温めて」おくと、決済往復後のアップロードで失敗しにくい。
  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  /// 注文の画像をアップロードし、全て成功したら Firestore に1回だけ書き込む。
  ///
  /// - 部分失敗対策: 全画像のアップロード成功を待ってから Firestore に書くため、
  ///   途中で失敗した注文は「写真あり扱い」にならない（all-or-nothing）。
  /// - 冪等性: ファイル名を `image_{index}.png` に固定するので、リトライ時は
  ///   同じパスへ上書きされ、重複ファイルが増えない。
  ///
  /// 失敗時は [OrderUploadException] を投げる（呼び出し側でリトライUIを出す）。
  Future<void> uploadOrder(OrderRecord order) async {
    final uid = await ensureSignedIn();
    final localPaths = order.resolvedImagePaths;

    if (localPaths.isEmpty) {
      throw OrderUploadException('アップロードする画像がありません');
    }

    // 1) 全画像を Storage へアップロード
    final storagePaths = <String>[];
    for (var i = 0; i < localPaths.length; i++) {
      final file = File(localPaths[i]);
      if (!file.existsSync()) {
        throw OrderUploadException('画像ファイルが見つかりません: ${localPaths[i]}');
      }
      final storagePath = 'orders/$uid/${order.orderNumber}/image_$i.png';
      try {
        await _storage.ref(storagePath).putFile(
              file,
              SettableMetadata(contentType: 'image/png'),
            );
      } on FirebaseException catch (e) {
        throw OrderUploadException('画像のアップロードに失敗しました: ${e.message}');
      }
      storagePaths.add(storagePath);
    }

    // 2) 全アップロード成功後に Firestore へ1回だけ書き込む（決済側の paid は Webhook が merge）
    try {
      await _firestore.collection('orders').doc(order.orderNumber).set({
        'uid': uid,
        'orderNumber': order.orderNumber,
        'productType': order.productType,
        'petNames': order.petNames,
        'quantity': order.quantity,
        'nfcProxy': order.nfcProxy,
        'note': order.note,
        'imagePaths': storagePaths,
        'amount': order.amount,
        'uploaded': true,
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw OrderUploadException('注文情報の保存に失敗しました: ${e.message}');
    }
  }
}

/// 注文アップロードの失敗を表す例外（ユーザーにリトライを促すために使う）
class OrderUploadException implements Exception {
  final String message;
  OrderUploadException(this.message);

  @override
  String toString() => message;
}
