import 'package:adivery/adivery_ads.dart';
import 'package:flutter/material.dart';
import '../ad_config.dart';

class AdiveryBannerWidget extends StatelessWidget {
  final String? placementId;
  final BannerAdSize bannerSize;

  const AdiveryBannerWidget({
    super.key,
    this.placementId,
    this.bannerSize = BannerAdSize.BANNER,
  });

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.isSupported) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AdConfig.bannerNotifier,
      builder: (context, isEnabled, child) {
        if (!isEnabled) {
          return const SizedBox.shrink();
        }

        final placement = placementId ?? AdConfig.bannerPlacementId;
        if (placement.isEmpty) {
          return const SizedBox.shrink();
        }

        return Center(
          child: BannerAd(
            placement,
            bannerSize,
            onAdLoaded: (ad) => debugPrint('Adivery Banner loaded: $placement'),
            onError: (ad, error) =>
                debugPrint('Adivery Banner error: $error on $placement'),
          ),
        );
      },
    );
  }
}
