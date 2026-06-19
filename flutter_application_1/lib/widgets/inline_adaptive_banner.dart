import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

import '../services/ad_units.dart';

class InlineAdaptiveBanner extends StatefulWidget {
  const InlineAdaptiveBanner({
    super.key,
    this.horizontalMargin = 16,
    this.verticalMargin = 12,
    this.maxHeight = 120, // Keep API identical to avoid breaking other files
  });

  final double horizontalMargin;
  final double verticalMargin;
  final int maxHeight;

  @override
  State<InlineAdaptiveBanner> createState() => _InlineAdaptiveBannerState();
}

class _InlineAdaptiveBannerState extends State<InlineAdaptiveBanner> {
  final _startAppSdk = StartAppSdk();
  StartAppBannerAd? _bannerAd;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (!AdUnits.isSupported) {
      setState(() => _isLoading = false);
      return;
    }

    _startAppSdk.loadBannerAd(StartAppBannerType.BANNER).then((ad) {
      if (mounted) {
        setState(() {
          _bannerAd = ad;
          _isLoading = false;
        });
      }
    }).catchError((error) {
      debugPrint('StartApp banner failed to load: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AdUnits.isSupported) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.horizontalMargin,
          vertical: widget.verticalMargin,
        ),
        child: SizedBox(
          height: 50, // Standard banner height
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
        ),
      );
    }

    if (_bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalMargin,
        vertical: widget.verticalMargin,
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: StartAppBanner(_bannerAd!),
          ),
        ),
      ),
    );
  }
}
