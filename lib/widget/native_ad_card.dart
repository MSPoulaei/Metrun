import 'package:adivery/adivery_ads.dart';
import 'package:flutter/material.dart';
import '../ad_config.dart';

class NativeAdCard extends StatefulWidget {
  final String? placementId;
  final EdgeInsetsGeometry margin;

  const NativeAdCard({
    super.key,
    this.placementId,
    this.margin = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdConfig.isSupported || !AdConfig.nativeEnabled) return;

    final placement = widget.placementId ?? AdConfig.nativePlacementId;
    if (placement.isEmpty) return;

    _nativeAd = NativeAd(
      placement,
      onAdLoaded: () {
        if (!mounted) return;
        setState(() {
          _isLoaded = true;
        });
      },
      onError: (error) {
        debugPrint('Adivery NativeAd error: $error');
        if (!mounted) return;
        setState(() {
          _isLoaded = false;
        });
      },
    );
    _nativeAd?.loadAd();
  }

  @override
  void dispose() {
    _nativeAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null || _nativeAd?.isLoaded != true) {
      return const SizedBox.shrink();
    }

    final ad = _nativeAd!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        margin: widget.margin,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ad.recordClick(),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: Icon, Advertiser/Headline, and Sponsored badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (ad.icon != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: ad.icon!,
                        ),
                      ),
                    if (ad.icon != null) const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ad.headline != null && ad.headline!.isNotEmpty)
                            Text(
                              ad.headline!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (ad.advertiser != null && ad.advertiser!.isNotEmpty)
                            Text(
                              ad.advertiser!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sponsored Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'تبلیغ',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                // Description
                if (ad.description != null && ad.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ad.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Main Image banner (if available)
                if (ad.image != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ad.image!,
                    ),
                  ),
                ],

                // Action button
                if (ad.callToAction != null && ad.callToAction!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: () => ad.recordClick(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        ad.callToAction!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
