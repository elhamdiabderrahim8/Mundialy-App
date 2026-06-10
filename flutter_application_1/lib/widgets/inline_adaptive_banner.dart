import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_units.dart';

class InlineAdaptiveBanner extends StatefulWidget {
  const InlineAdaptiveBanner({
    super.key,
    this.horizontalMargin = 16,
    this.verticalMargin = 12,
    this.maxHeight = 120,
  });

  final double horizontalMargin;
  final double verticalMargin;
  final int maxHeight;

  @override
  State<InlineAdaptiveBanner> createState() => _InlineAdaptiveBannerState();
}

class _InlineAdaptiveBannerState extends State<InlineAdaptiveBanner> {
  BannerAd? _bannerAd;
  AdSize? _loadedSize;
  bool _isLoaded = false;
  int? _requestedWidth;
  Orientation? _requestedOrientation;

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd(int width, Orientation orientation) async {
    final adUnitId = AdUnits.inlineBanner;
    if (adUnitId.isEmpty || width <= 0) return;
    if (_requestedWidth == width && _requestedOrientation == orientation) {
      return;
    }

    _requestedWidth = width;
    _requestedOrientation = orientation;
    _isLoaded = false;
    _loadedSize = null;
    await _bannerAd?.dispose();
    _bannerAd = null;

    final size = AdSize.getInlineAdaptiveBannerAdSize(
      width,
      widget.maxHeight,
    );

    final banner = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final bannerAd = ad as BannerAd;
          final platformSize = await bannerAd.getPlatformAdSize();
          if (!mounted || platformSize == null) {
            await bannerAd.dispose();
            return;
          }
          setState(() {
            _bannerAd = bannerAd;
            _loadedSize = platformSize;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inline banner failed to load: $error');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _loadedSize = null;
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd = banner;
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdUnits.isSupported || AdUnits.inlineBanner.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final orientation = MediaQuery.orientationOf(context);
        final width = (constraints.maxWidth - (widget.horizontalMargin * 2))
            .clamp(0, constraints.maxWidth)
            .truncate();

        if (width > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadAd(width, orientation);
          });
        }

        if (!_isLoaded || _bannerAd == null || _loadedSize == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalMargin,
            vertical: widget.verticalMargin,
          ),
          child: Center(
            child: SizedBox(
              width: _loadedSize!.width.toDouble(),
              height: _loadedSize!.height.toDouble(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ),
        );
      },
    );
  }
}
