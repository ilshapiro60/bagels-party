import 'package:flutter/material.dart';

import '../config/assets.dart';
import '../config/theme.dart';

/// Full-width lifestyle hero — fades into the app scaffold background for a soft, upbeat feel.
///
/// [imageAlignment] controls which part of the photo stays visible under [BoxFit.cover]
/// (e.g. bias toward [Alignment.topCenter] when faces sit in the upper area of the asset).
class PawPartyHeroBanner extends StatelessWidget {
  const PawPartyHeroBanner({
    super.key,
    this.height = 200,
    this.borderRadius,
    this.imageAlignment = Alignment.center,
  });

  final double height;
  final BorderRadius? borderRadius;
  /// Where to anchor the image when it is cropped (narrow banners need a strong top bias for faces).
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = (MediaQuery.sizeOf(context).width * dpr).round();
    final radius = borderRadius ??
        const BorderRadius.vertical(bottom: Radius.circular(28));
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              PawPartyAssets.homeHeroPets,
              fit: BoxFit.contain,
              alignment: imageAlignment,
              cacheWidth: decodeW,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: PawPartyColors.surfaceVariant,
                child: Icon(
                  Icons.pets,
                  size: 48,
                  color: PawPartyColors.primary.withValues(alpha: 0.35),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    PawPartyColors.rugTeal.withValues(alpha: 0.12),
                    Colors.transparent,
                    PawPartyColors.background.withValues(alpha: 0.65),
                    PawPartyColors.background,
                  ],
                  stops: const [0, 0.25, 0.7, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
