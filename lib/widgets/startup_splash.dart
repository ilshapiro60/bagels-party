import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Shown while auth session restores.
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  static const _splashBg = Color(0xFF0A0E18);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Explicit box + [BoxFit.contain] keeps aspect ratio (avoid horizontal squeeze
                    // from height-only sizing inside a [Column]).
                    final maxW = constraints.maxWidth;
                    final maxH = MediaQuery.sizeOf(context).height * 0.42;
                    return SizedBox(
                      width: maxW,
                      height: maxH,
                      child: Image.asset(
                        'assets/images/zumitok_logo.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.pets,
                          size: 72,
                          color: PawPartyColors.secondary.withValues(alpha: 0.85),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF4DD0E1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
