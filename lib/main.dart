import 'dart:async';

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

  // 軽量な初期化を並行で実行（起動時間短縮）
  await Future.wait([
    _initFirebase(),
    PathResolver.init(),
    AppPreferences.init(),
  ]);

  // 課金状態は広告表示判定（shouldShowAds）に必要なので順次 await
  await PurchaseManager.instance.initialize();

  // 広告SDK と ONNX ランタイムは非ブロッキング（runApp 後にバックグラウンドで完了）
  // - 広告SDK: UMP同意フローで最大10秒待つ可能性があるため、起動を引っ張らせない
  // - ONNX: 数秒のロード時間。背景自動削除を初めて使う時までに完了していればOK
  unawaited(AdManager.instance.initialize());
  unawaited(
    BackgroundRemover.instance.initializeOrt().catchError((e) {
      debugPrint('BackgroundRemover init failed: $e');
    }),
  );

  runApp(const ProviderScope(child: MofumofuApp()));
}

/// Firebase 初期化 + Crashlytics 設定（Future.wait で並行実行できるよう関数化）
Future<void> _initFirebase() async {
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
      // 全画面共通: 背景タップでキーボードを閉じる
      // TextField やボタン上のタップは各 Widget がイベントを消費するため干渉しない
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: child,
        );
      },
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
