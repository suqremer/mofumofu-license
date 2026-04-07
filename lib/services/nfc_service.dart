import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// NFC読み取り結果
enum NfcReadResult {
  success,
  notUchinokoData, // うちの子免許証のデータではない
  noNdef, // NDEFデータなし
  readFailed,
  notAvailable,
  timeout,
}

/// NFC読み取りレスポンス
class NfcReadResponse {
  final NfcReadResult result;
  final String? text;
  final String? errorDetail;

  const NfcReadResponse(this.result, {this.text, this.errorDetail});
}

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

  /// NFC情報表示ページのベースURL
  static const String nfcPageBaseUrl = 'https://uchinoko-license.com/n/';

  /// テキストのバイト数を計算（UTF-8）
  static int calculateBytes(String text) {
    return utf8.encode(text).length;
  }

  /// NDEFメッセージ全体のおおよそのバイト数を計算
  /// （実効ペイロード = 全レコードのpayload + ヘッダーオーバーヘッド）
  static int estimateNdefMessageBytes(NdefMessage message) {
    int total = 0;
    for (final record in message.records) {
      // 各レコードのオーバーヘッド：ヘッダー(1) + type長(1) + payload長(1〜4) + type
      total += 4 + record.type.length + record.payload.length;
    }
    // TLV等の追加オーバーヘッド
    total += 6;
    return total;
  }

  /// NFCタグに書き込むURI（GitHub Pages + Base64データ）を生成
  static String buildNfcUri({
    required String petName,
    required String breed,
    required String ownerName,
    required String phoneNumber,
    String? note,
  }) {
    final data = <String, String>{
      'n': petName,
      'b': breed,
      'o': ownerName,
      't': phoneNumber,
    };
    if (note != null && note.isNotEmpty) {
      data['r'] = note;
    }
    final jsonStr = jsonEncode(data);
    final base64Str = base64Encode(utf8.encode(jsonStr));
    return '$nfcPageBaseUrl#$base64Str';
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
            if (completer.isCompleted) return;

            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              if (!completer.isCompleted) {
                completer.complete(const NfcWriteResponse(
                  NfcWriteResult.writeFailed, 'Ndef.from returned null or not writable'));
              }
              NfcManager.instance.stopSession(errorMessage: 'このタグは書き込みに対応していません');
              return;
            }

            if (ndef.maxSize < bytes) {
              if (!completer.isCompleted) {
                completer.complete(const NfcWriteResponse(NfcWriteResult.capacityExceeded));
              }
              NfcManager.instance.stopSession(errorMessage: 'タグの容量が不足しています');
              return;
            }

            final message = NdefMessage([
              NdefRecord.createText(text),
            ]);

            await ndef.write(message);
            if (!completer.isCompleted) {
              completer.complete(const NfcWriteResponse(NfcWriteResult.success));
            }
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

  /// NFCタグにうちの子免許証データを書き込む
  ///
  /// URIレコード（GitHub Pages + Base64データ）+ テキストレコードの2つを書き込む。
  /// URIレコードを1番目に置くことで、iPhoneのバックグラウンド読み取りで自動通知される。
  Future<NfcWriteResponse> writeUchinokoTag({
    required String petName,
    required String breed,
    required String ownerName,
    required String phoneNumber,
    String? note,
    VoidCallback? onTagDiscovered,
    int timeoutSeconds = 30,
  }) async {
    if (!await isAvailable()) {
      return const NfcWriteResponse(NfcWriteResult.notAvailable);
    }

    // URIとテキストの両方を生成
    final uri = buildNfcUri(
      petName: petName,
      breed: breed,
      ownerName: ownerName,
      phoneNumber: phoneNumber,
      note: note,
    );
    final text = buildNfcText(
      petName: petName,
      breed: breed,
      ownerName: ownerName,
      phoneNumber: phoneNumber,
      note: note,
    );

    // 2レコード（URI + テキスト）のNDEFメッセージを構築
    // URIレコードを1番目に置くこと（iOSバックグラウンド読み取りは1番目しか見ない）
    final message = NdefMessage([
      NdefRecord.createUri(Uri.parse(uri)),
      NdefRecord.createText(text),
    ]);

    final estimatedBytes = estimateNdefMessageBytes(message);
    if (estimatedBytes > maxCapacity) {
      return const NfcWriteResponse(NfcWriteResult.capacityExceeded);
    }

    final completer = Completer<NfcWriteResponse>();

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
            if (completer.isCompleted) return;

            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              if (!completer.isCompleted) {
                completer.complete(const NfcWriteResponse(
                    NfcWriteResult.writeFailed,
                    'Ndef.from returned null or not writable'));
              }
              NfcManager.instance
                  .stopSession(errorMessage: 'このタグは書き込みに対応していません');
              return;
            }

            if (ndef.maxSize < estimatedBytes) {
              if (!completer.isCompleted) {
                completer.complete(
                    const NfcWriteResponse(NfcWriteResult.capacityExceeded));
              }
              NfcManager.instance
                  .stopSession(errorMessage: 'タグの容量が不足しています');
              return;
            }

            await ndef.write(message);
            if (!completer.isCompleted) {
              completer
                  .complete(const NfcWriteResponse(NfcWriteResult.success));
            }
            NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint('NFC writeUchinokoTag error: $e');
            if (!completer.isCompleted) {
              completer.complete(NfcWriteResponse(
                  NfcWriteResult.writeFailed, 'onDiscovered error: $e'));
            }
            NfcManager.instance.stopSession(errorMessage: '書き込みに失敗しました');
          }
        },
        onError: (error) async {
          debugPrint('NFC session error: $error');
          final detail =
              'onError: type=${error.type}, message=${error.message}';
          if (!completer.isCompleted) {
            completer.complete(
                NfcWriteResponse(NfcWriteResult.writeFailed, detail));
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

  /// うちの子免許証のデータかどうか判定
  static bool isUchinokoData(String text) {
    return text.startsWith('\u{1F43E} うちの子免許証') &&
        text.contains('ペット名:');
  }

  /// NDEFテキストレコードをデコード
  static String? decodeNdefTextRecord(NdefRecord record) {
    final payload = record.payload;
    if (payload.isEmpty) return null;
    final langCodeLength = payload[0] & 0x3F;
    if (payload.length <= 1 + langCodeLength) return null;
    final textBytes = payload.sublist(1 + langCodeLength);
    return utf8.decode(textBytes, allowMalformed: true);
  }

  /// NFCタグからテキストを読み取る
  Future<NfcReadResponse> readTag({
    int timeoutSeconds = 30,
  }) async {
    if (!await isAvailable()) {
      return const NfcReadResponse(NfcReadResult.notAvailable);
    }

    final completer = Completer<NfcReadResponse>();

    final timer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        NfcManager.instance.stopSession();
        completer.complete(const NfcReadResponse(NfcReadResult.timeout));
      }
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        alertMessage: 'ペットタグをかざしてください',
        onDiscovered: (NfcTag tag) async {
          try {
            if (completer.isCompleted) return;

            final ndef = Ndef.from(tag);
            if (ndef == null) {
              if (!completer.isCompleted) {
                completer.complete(const NfcReadResponse(NfcReadResult.noNdef));
              }
              NfcManager.instance.stopSession(
                  errorMessage: 'このタグにはデータがありません');
              return;
            }

            // cachedMessage を優先、なければ read()
            var message = ndef.cachedMessage;
            message ??= await ndef.read();

            if (message.records.isEmpty) {
              if (!completer.isCompleted) {
                completer.complete(const NfcReadResponse(NfcReadResult.noNdef));
              }
              NfcManager.instance.stopSession(
                  errorMessage: 'このタグにはデータがありません');
              return;
            }

            // テキストレコードを探す
            String? text;
            for (final record in message.records) {
              if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
                  record.type.length == 1 &&
                  record.type[0] == 0x54) {
                text = decodeNdefTextRecord(record);
                if (text != null) break;
              }
            }

            if (text == null) {
              if (!completer.isCompleted) {
                completer.complete(const NfcReadResponse(
                  NfcReadResult.noNdef,
                  errorDetail: 'テキストレコードが見つかりません',
                ));
              }
              NfcManager.instance.stopSession(
                  errorMessage: 'テキストデータが見つかりません');
              return;
            }

            if (!isUchinokoData(text)) {
              if (!completer.isCompleted) {
                completer.complete(NfcReadResponse(
                  NfcReadResult.notUchinokoData,
                  text: text,
                ));
              }
              NfcManager.instance.stopSession(
                  alertMessage: '読み取り完了');
              return;
            }

            if (!completer.isCompleted) {
              completer.complete(NfcReadResponse(
                NfcReadResult.success,
                text: text,
              ));
            }
            NfcManager.instance.stopSession(alertMessage: '読み取り完了！');
          } catch (e) {
            debugPrint('NFC read error: $e');
            if (!completer.isCompleted) {
              completer.complete(NfcReadResponse(
                NfcReadResult.readFailed,
                errorDetail: 'onDiscovered error: $e',
              ));
            }
            NfcManager.instance.stopSession(
                errorMessage: '読み取りに失敗しました');
          }
        },
        onError: (error) async {
          debugPrint('NFC read session error: $error');
          if (!completer.isCompleted) {
            completer.complete(NfcReadResponse(
              NfcReadResult.readFailed,
              errorDetail: 'onError: type=${error.type}, message=${error.message}',
            ));
          }
        },
      );
    } catch (e) {
      debugPrint('NFC read start session error: $e');
      timer.cancel();
      if (!completer.isCompleted) {
        return NfcReadResponse(
          NfcReadResult.readFailed,
          errorDetail: 'startSession threw: $e',
        );
      }
    }

    final result = await completer.future;
    timer.cancel();
    return result;
  }

  /// NFCタグの内容を消去（空のNDEFメッセージを書き込み）
  Future<NfcWriteResponse> eraseTag({
    int timeoutSeconds = 30,
  }) async {
    if (!await isAvailable()) {
      return const NfcWriteResponse(NfcWriteResult.notAvailable);
    }

    final completer = Completer<NfcWriteResponse>();

    final timer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        NfcManager.instance.stopSession();
        completer.complete(const NfcWriteResponse(NfcWriteResult.timeout));
      }
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        alertMessage: '消去するタグをかざしてください',
        onDiscovered: (NfcTag tag) async {
          try {
            if (completer.isCompleted) return;

            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              if (!completer.isCompleted) {
                completer.complete(const NfcWriteResponse(
                  NfcWriteResult.writeFailed, 'タグが書き込みに対応していません'));
              }
              NfcManager.instance.stopSession(errorMessage: 'このタグは書き込みに対応していません');
              return;
            }

            // 空のNDEFメッセージで上書き
            final emptyMessage = NdefMessage([
              NdefRecord.createText(''),
            ]);

            await ndef.write(emptyMessage);
            if (!completer.isCompleted) {
              completer.complete(const NfcWriteResponse(NfcWriteResult.success));
            }
            NfcManager.instance.stopSession(alertMessage: '消去しました！');
          } catch (e) {
            debugPrint('NFC erase error: $e');
            if (!completer.isCompleted) {
              completer.complete(NfcWriteResponse(
                NfcWriteResult.writeFailed, 'erase error: $e'));
            }
            NfcManager.instance.stopSession(errorMessage: '消去に失敗しました');
          }
        },
        onError: (error) async {
          debugPrint('NFC erase session error: $error');
          if (!completer.isCompleted) {
            completer.complete(NfcWriteResponse(
              NfcWriteResult.writeFailed, 'onError: ${error.message}'));
          }
        },
      );
    } catch (e) {
      debugPrint('NFC erase start session error: $e');
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
