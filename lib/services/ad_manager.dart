import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import '../config/dev_config.dart';
import 'purchase_manager.dart';

/// AdMob広告の初期化・ロード・表示を管理するシングルトン
///
/// アプリ起動時に [initialize] を呼び出すこと。
/// kDevMode=true の場合、広告は一切表示しない。
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  /// 広告を表示すべきか（kDevMode / プレミアム購入済みなら非表示）
  bool get shouldShowAds => !kDevMode && !PurchaseManager.instance.isPremium;

  /// ATT + UMP同意 + MobileAds SDK を初期化
  ///
  /// 1. ATT（App Tracking Transparency）ダイアログを表示（iOS）
  /// 2. UMP で同意情報を更新（GDPR対応）
  /// 3. 同意フォームが必要なら表示
  /// 4. 同意完了後に MobileAds を初期化
  Future<void> initialize() async {
    if (_initialized || !shouldShowAds) return;

    // ATT ダイアログ（iOS 14.5+ 必須）
    if (Platform.isIOS) {
      try {
        final status =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('AdMob: ATT status: $status');
      } catch (e) {
        debugPrint('AdMob: ATT error (continuing): $e');
      }
    }

    // UMP 同意フロー（10秒でタイムアウト → 無限ハング防止）
    try {
      await _requestConsent().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('AdMob: Consent flow timed out (continuing)');
        },
      );
      debugPrint('AdMob: Consent flow completed');
    } catch (e) {
      // 同意フロー失敗でも広告初期化は続行（非パーソナライズ広告になる）
      debugPrint('AdMob: Consent error (continuing): $e');
    }

    // MobileAds 初期化
    await MobileAds.instance.initialize();
    _initialized = true;
    debugPrint('AdMob: SDK initialized');
  }

  /// UMP 同意情報を更新し、必要なら同意フォームを表示
  Future<void> _requestConsent() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        // 同意情報更新成功 → フォームが必要なら表示
        try {
          final available =
              await ConsentInformation.instance.isConsentFormAvailable();
          if (available) {
            ConsentForm.loadAndShowConsentFormIfRequired(
              (formError) {
                if (formError != null) {
                  debugPrint('AdMob: Consent form error: ${formError.message}');
                }
                completer.complete();
              },
            );
          } else {
            completer.complete();
          }
        } catch (e) {
          completer.complete();
        }
      },
      (formError) {
        // 同意情報更新失敗
        debugPrint('AdMob: Consent info update failed: ${formError.message}');
        completer.complete();
      },
    );

    return completer.future;
  }

  // ─────────────────────────────────────────────
  // バナー広告
  // ─────────────────────────────────────────────

  /// バナー広告を生成してロード
  ///
  /// 呼び出し側の Widget で dispose する責任がある。
  BannerAd createBannerAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    return BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('AdMob: Banner loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob: Banner failed to load: $error');
          ad.dispose();
          onFailed?.call();
        },
      ),
    )..load();
  }

  // ─────────────────────────────────────────────
  // インタースティシャル広告
  // ─────────────────────────────────────────────

  /// インタースティシャル広告を事前ロード
  void preloadInterstitial() {
    if (!shouldShowAds) return;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          debugPrint('AdMob: Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;
          debugPrint('AdMob: Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// インタースティシャル広告を表示
  ///
  /// 表示完了（閉じた or 失敗）後に [onDismissed] が呼ばれる。
  void showInterstitial({VoidCallback? onDismissed}) {
    if (!shouldShowAds || !_isInterstitialReady || _interstitialAd == null) {
      onDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        onDismissed?.call();
        // 次回用に事前ロード
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: Interstitial failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        onDismissed?.call();
        preloadInterstitial();
      },
    );

    _interstitialAd!.show();
  }

  /// リソース解放
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;
  }
}
