import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mofumofu_license/models/order_record.dart';

void main() {
  group('OrderRecord', () {
    final now = DateTime(2026, 6, 15, 12, 0, 0);

    /// 全フィールドを持つテスト用Map
    Map<String, dynamic> fullMap() => {
          'order_number': 'UNK-20260615-7K2QF9',
          'product_type': 'set',
          'pet_names': '["ココ","モモ"]',
          'quantity': 2,
          'nfc_proxy': 1,
          'note': '備考テスト',
          'image_paths': '["orders/abc/card_0.png","orders/abc/tag_0.png"]',
          'amount': 7960,
          'status': 'uploaded',
          'session_id': 'cs_test_123',
          'created_at': now.toIso8601String(),
        };

    /// 必須＋任意nullのテスト用Map
    Map<String, dynamic> minimalMap() => {
          'order_number': 'UNK-20260615-AAAAAA',
          'product_type': 'card',
          'pet_names': '["ポチ"]',
          'quantity': 1,
          'nfc_proxy': 0,
          'note': null,
          'image_paths': '[]',
          'amount': 2280,
          'status': 'pending',
          'session_id': null,
          'created_at': now.toIso8601String(),
        };

    group('generateOrderNumber', () {
      test('UNK-YYYYMMDD-XXXXXX 形式で生成される', () {
        final num = OrderRecord.generateOrderNumber(now, Random(1));
        expect(num, matches(RegExp(r'^UNK-\d{8}-[A-Z2-9]{6}$')));
      });

      test('日付部分が渡した日時と一致する', () {
        final num = OrderRecord.generateOrderNumber(now, Random(1));
        expect(num, startsWith('UNK-20260615-'));
      });

      test('1桁の月日はゼロ埋めされる', () {
        final num = OrderRecord.generateOrderNumber(
          DateTime(2026, 1, 5),
          Random(1),
        );
        expect(num, startsWith('UNK-20260105-'));
      });

      test('紛らわしい文字（0 1 O I L）を含まない', () {
        // 多数生成してコード部分に禁止文字が出ないことを確認
        final rnd = Random(99);
        for (var i = 0; i < 200; i++) {
          final code = OrderRecord.generateOrderNumber(now, rnd).split('-').last;
          expect(code.contains(RegExp(r'[01OIL]')), isFalse,
              reason: 'code=$code に紛らわしい文字が含まれている');
        }
      });

      test('同じシードなら決定的、異なるシードなら異なりうる', () {
        final a = OrderRecord.generateOrderNumber(now, Random(7));
        final b = OrderRecord.generateOrderNumber(now, Random(7));
        final c = OrderRecord.generateOrderNumber(now, Random(8));
        expect(a, b);
        expect(a, isNot(c));
      });
    });

    group('fromMap', () {
      test('全フィールドが正しくパースされる', () {
        final o = OrderRecord.fromMap(fullMap());

        expect(o.orderNumber, 'UNK-20260615-7K2QF9');
        expect(o.productType, 'set');
        expect(o.petNames, ['ココ', 'モモ']);
        expect(o.quantity, 2);
        expect(o.nfcProxy, isTrue);
        expect(o.note, '備考テスト');
        expect(o.imagePaths, ['orders/abc/card_0.png', 'orders/abc/tag_0.png']);
        expect(o.amount, 7960);
        expect(o.status, OrderStatus.uploaded);
        expect(o.sessionId, 'cs_test_123');
        expect(o.createdAt, now);
      });

      test('任意フィールドがnullでもパースできる', () {
        final o = OrderRecord.fromMap(minimalMap());

        expect(o.nfcProxy, isFalse);
        expect(o.note, isNull);
        expect(o.imagePaths, isEmpty);
        expect(o.status, OrderStatus.pending);
        expect(o.sessionId, isNull);
      });

      test('未知のstatus文字列はpendingにフォールバックする', () {
        final map = minimalMap()..['status'] = 'unknown_value';
        expect(OrderRecord.fromMap(map).status, OrderStatus.pending);
      });
    });

    group('toMap', () {
      test('リストはJSON文字列、boolは0/1、statusはnameに変換される', () {
        final o = OrderRecord.fromMap(fullMap());
        final map = o.toMap();

        expect(map['order_number'], 'UNK-20260615-7K2QF9');
        expect(map['product_type'], 'set');
        expect(map['pet_names'], '["ココ","モモ"]');
        expect(map['quantity'], 2);
        expect(map['nfc_proxy'], 1);
        expect(map['note'], '備考テスト');
        expect(map['image_paths'], '["orders/abc/card_0.png","orders/abc/tag_0.png"]');
        expect(map['amount'], 7960);
        expect(map['status'], 'uploaded');
        expect(map['session_id'], 'cs_test_123');
        expect(map['created_at'], now.toIso8601String());
      });

      test('nfc_proxy false は 0 になる', () {
        final o = OrderRecord.fromMap(minimalMap());
        expect(o.toMap()['nfc_proxy'], 0);
      });
    });

    group('ラウンドトリップ', () {
      test('fromMap -> toMap -> fromMap で値が保たれる', () {
        final o1 = OrderRecord.fromMap(fullMap());
        final o2 = OrderRecord.fromMap(o1.toMap());

        expect(o2.orderNumber, o1.orderNumber);
        expect(o2.productType, o1.productType);
        expect(o2.petNames, o1.petNames);
        expect(o2.quantity, o1.quantity);
        expect(o2.nfcProxy, o1.nfcProxy);
        expect(o2.note, o1.note);
        expect(o2.imagePaths, o1.imagePaths);
        expect(o2.amount, o1.amount);
        expect(o2.status, o1.status);
        expect(o2.sessionId, o1.sessionId);
        expect(o2.createdAt, o1.createdAt);
      });
    });

    group('copyWith', () {
      test('一部だけ変更し、他は保たれる', () {
        final o = OrderRecord.fromMap(minimalMap());
        final updated = o.copyWith(
          status: OrderStatus.uploaded,
          sessionId: 'cs_live_xxx',
        );

        expect(updated.status, OrderStatus.uploaded);
        expect(updated.sessionId, 'cs_live_xxx');
        // 変更していないフィールドは元のまま
        expect(updated.orderNumber, o.orderNumber);
        expect(updated.productType, o.productType);
        expect(updated.amount, o.amount);
      });

      test('元のインスタンスは変更されない', () {
        final o = OrderRecord.fromMap(minimalMap());
        o.copyWith(status: OrderStatus.uploaded);
        expect(o.status, OrderStatus.pending);
      });
    });

    group('OrderStatus.fromName', () {
      test('有効な名前を解決する', () {
        expect(OrderStatus.fromName('pending'), OrderStatus.pending);
        expect(OrderStatus.fromName('uploaded'), OrderStatus.uploaded);
      });

      test('null・不正値は pending にフォールバック', () {
        expect(OrderStatus.fromName(null), OrderStatus.pending);
        expect(OrderStatus.fromName('xxx'), OrderStatus.pending);
      });
    });
  });
}
