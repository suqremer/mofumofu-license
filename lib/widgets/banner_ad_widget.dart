import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_manager.dart';

/// バナー広告を表示する共通Widget
///
/// [AdManager.shouldShowAds] が false の場合は何も表示しない。
/// 広告のロード・破棄を自動管理する。
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdManager.instance.shouldShowAds) {
      _bannerAd = AdManager.instance.createBannerAd(
        onLoaded: () {
          if (mounted) setState(() => _isLoaded = true);
        },
        onFailed: () {
          if (mounted) setState(() => _isLoaded = false);
        },
      );
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.shouldShowAds || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
