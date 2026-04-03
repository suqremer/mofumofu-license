import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_background_remover/image_background_remover.dart';

import 'config/ad_config.dart';
import 'config/dev_config.dart';
import 'router.dart';
import 'services/ad_manager.dart';
import 'services/app_preferences.dart';
import 'services/path_resolver.dart';
import 'services/purchase_manager.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // リリースビルドで開発フラグが残っていたら即座にエラー（出荷事故防止）
  if (kReleaseMode) {
    if (kDevMode) {
      throw StateError(
        'kDevMode が true のままリリースビルドされています！'
        'lib/config/dev_config.dart を false に変更してください',
      );
    }
    if (AdConfig.kUseTestAds) {
      // TestFlight テスト中はテスト広告を許容する。
      // 本番提出時は kUseTestAds = false に変更すること。
      debugPrint('⚠️ WARNING: kUseTestAds is true in release build');
    }
  }

  // フォントはアプリにバンドル済み。ネットからのダウンロードを禁止
  GoogleFonts.config.allowRuntimeFetching = false;

  // Firebase初期化
  try {
    await Firebase.initializeApp();

    // Crashlytics設定（デバッグ時は無効）
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  await PathResolver.init();
  await AppPreferences.init();
  await PurchaseManager.instance.initialize();
  await AdManager.instance.initialize();

  // 背景自動削除用 ONNX ランタイム初期化（バックグラウンドで実行、起動をブロックしない）
  BackgroundRemover.instance.initializeOrt().catchError((e) {
    debugPrint('BackgroundRemover init failed: $e');
  });

  runApp(const ProviderScope(child: MofumofuApp()));
}

class MofumofuApp extends StatelessWidget {
  const MofumofuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'うちの子免許証',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // 日本語ローカリゼーション
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'),
      ],
    );
  }
}
