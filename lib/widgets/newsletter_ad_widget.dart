import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/theme.dart';

class NewsletterAdWidget extends StatefulWidget {
  const NewsletterAdWidget({super.key});

  @override
  State<NewsletterAdWidget> createState() => _NewsletterAdWidgetState();
}

class _NewsletterAdWidgetState extends State<NewsletterAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  static String get _adUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2247696110'
      : 'ca-app-pub-3940256099942544/3986624511';

  @override
  void initState() {
    super.initState();
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _nativeAd = null);
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: PawPartyColors.surface,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          size: 13,
          backgroundColor: PawPartyColors.primary,
          textColor: Colors.white,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          size: 14,
          textColor: PawPartyColors.textPrimary,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          size: 12,
          textColor: PawPartyColors.textSecondary,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          size: 11,
          textColor: PawPartyColors.textHint,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PawPartyColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Sponsored',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: PawPartyColors.textHint,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 90,
              maxHeight: 120,
            ),
            child: AdWidget(ad: _nativeAd!),
          ),
        ],
      ),
    );
  }
}
