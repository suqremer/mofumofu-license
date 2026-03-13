import 'dart:io';

/// AdMob 広告ユニットID管理
///
/// テスト用IDと本番用IDを一元管理。
/// [kUseTestAds] を false に変更して本番IDをセットしてからリリースすること。
///
/// ★★★ 公開前に kUseTestAds = false にして本番IDを設定すること！ ★★★
class AdConfig {
  AdConfig._();

  /// テスト広告を使うか（開発中は true）
  static const bool kUseTestAds = true;

  // ── 本番用 Ad Unit ID（リリース前にセット） ──
  static const String _prodBannerAndroid =
      'ca-app-pub-3721612777407461/5354156889';
  static const String _prodBannerIos =
      'ca-app-pub-3721612777407461/4048125716';
  static const String _prodInterstitialAndroid =
      'ca-app-pub-3721612777407461/4041075210';
  static const String _prodInterstitialIos =
      'ca-app-pub-3721612777407461/7876853805';

  // ── Google公式テスト用 Ad Unit ID ──
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';

  /// バナー広告のユニットID
  static String get bannerAdUnitId {
    if (kUseTestAds) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIos;
    }
    return Platform.isAndroid ? _prodBannerAndroid : _prodBannerIos;
  }

  /// インタースティシャル広告のユニットID
  static String get interstitialAdUnitId {
    if (kUseTestAds) {
      return Platform.isAndroid
          ? _testInterstitialAndroid
          : _testInterstitialIos;
    }
    return Platform.isAndroid
        ? _prodInterstitialAndroid
        : _prodInterstitialIos;
  }
}
