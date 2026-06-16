import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import '../router.dart';
import 'database_service.dart';

/// 決済後の着地ページからアプリへ復帰させるディープリンクを受信するサービス。
///
/// 着地ページの「アプリで写真を送る」ボタンは `mofumofulicense://...` を開く。
/// このカスタムスキームを受信したら、端末に一時保存した未送信注文（pending）を
/// 読み出して写真アップロード画面へ誘導する。
///
/// ※ どの注文かはリンクのパラメータではなく端末ローカルの pending から特定する
///   （Stripeのリダイレクトに乗るのは session_id で、受付番号ではないため）。
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  /// アプリのカスタムURLスキーム（Info.plist / AndroidManifest と一致させる）
  static const String _scheme = 'mofumofulicense';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// 受信の購読を開始する。main から一度だけ呼ぶ。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // アプリ起動中に届くリンク
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) => debugPrint('app_links stream error: $e'),
    );

    // コールドスタート時の初期リンク（アプリが起動していなかった場合）
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (e) {
      debugPrint('getInitialLink failed: $e');
    }
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != _scheme) return;
    // ルーター（MaterialApp.router）の描画後に遷移する
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumePendingUpload());
  }

  /// 未送信注文を読み出して写真アップロードへ誘導する。
  /// 1件なら直接アップロード画面、0件または複数件は注文履歴へ。
  Future<void> _resumePendingUpload() async {
    try {
      final pending = await DatabaseService().getPendingOrders();
      if (pending.length == 1) {
        router.push('/order/upload', extra: pending.first);
      } else {
        router.push('/order/history');
      }
    } catch (e) {
      debugPrint('deep link resume failed: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
