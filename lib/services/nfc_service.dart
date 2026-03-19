import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// NFC書き込み結果
enum NfcWriteResult {
  success,
  tagNotFound,
  capacityExceeded,
  writeFailed,
  notAvailable,
  timeout,
}

/// NFC書き込み結果 + エラー詳細
class NfcWriteResponse {
  final NfcWriteResult result;
  final String? errorDetail;

  const NfcWriteResponse(this.result, [this.errorDetail]);
}

/// NFC書き込みサービス
class NfcService {
  NfcService._();
  static final instance = NfcService._();

  /// 端末がNFCに対応しているか
  Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// NTAG215の有効容量（バイト）
  static const int maxCapacity = 504;

  /// テキストのバイト数を計算（UTF-8）
  static int calculateBytes(String text) {
    return utf8.encode(text).length;
  }

  /// NFC書き込みデータを生成
  static String buildNfcText({
    required String petName,
    required String breed,
    required String ownerName,
    required String phoneNumber,
    String? note,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\u{1F43E} うちの子免許証');
    buffer.writeln('ペット名: $petName');
    buffer.writeln('品種: $breed');
    buffer.writeln('飼い主: $ownerName');
    buffer.writeln('TEL: $phoneNumber');
    if (note != null && note.isNotEmpty) {
      buffer.writeln('特記: $note');
    }
    return buffer.toString();
  }

  /// NFCタグにテキストを書き込む
  ///
  /// [text] 書き込むテキスト
  /// [onTagDiscovered] タグ検出時のコールバック（UI更新用）
  /// [timeoutSeconds] タイムアウト秒数（デフォルト30秒）
  Future<NfcWriteResponse> writeText({
    required String text,
    VoidCallback? onTagDiscovered,
    int timeoutSeconds = 30,
  }) async {
    if (!await isAvailable()) {
      return const NfcWriteResponse(NfcWriteResult.notAvailable);
    }

    final bytes = calculateBytes(text);
    if (bytes > maxCapacity) {
      return const NfcWriteResponse(NfcWriteResult.capacityExceeded);
    }

    final completer = Completer<NfcWriteResponse>();

    // タイムアウトタイマー
    final timer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        NfcManager.instance.stopSession();
        completer.complete(const NfcWriteResponse(NfcWriteResult.timeout));
      }
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          onTagDiscovered?.call();

          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              completer.complete(const NfcWriteResponse(
                NfcWriteResult.writeFailed, 'Ndef.from returned null or not writable'));
              NfcManager.instance.stopSession(errorMessage: 'このタグは書き込みに対応していません');
              return;
            }

            if (ndef.maxSize < bytes) {
              completer.complete(const NfcWriteResponse(NfcWriteResult.capacityExceeded));
              NfcManager.instance.stopSession(errorMessage: 'タグの容量が不足しています');
              return;
            }

            final message = NdefMessage([
              NdefRecord.createText(text),
            ]);

            await ndef.write(message);
            completer.complete(const NfcWriteResponse(NfcWriteResult.success));
            NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint('NFC write error: $e');
            if (!completer.isCompleted) {
              completer.complete(NfcWriteResponse(
                NfcWriteResult.writeFailed, 'onDiscovered error: $e'));
            }
            NfcManager.instance.stopSession(errorMessage: '書き込みに失敗しました');
          }
        },
        onError: (error) async {
          debugPrint('NFC session error: $error');
          final detail = 'onError: type=${error.type}, message=${error.message}';
          if (!completer.isCompleted) {
            completer.complete(NfcWriteResponse(
              NfcWriteResult.writeFailed, detail));
          }
        },
      );
    } catch (e) {
      debugPrint('NFC start session error: $e');
      timer.cancel();
      if (!completer.isCompleted) {
        return NfcWriteResponse(
          NfcWriteResult.writeFailed, 'startSession threw: $e');
      }
    }

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  /// NFCセッションを停止
  void stopSession() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {
      // ignore
    }
  }
}
