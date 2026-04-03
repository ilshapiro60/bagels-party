import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';

/// Shown while auth session restores. Uses Bagel’s photo from [assets/images/bagel_splash_cat.png].
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawPartyColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 152,
                  height: 152,
                  child: Image.asset(
                    'assets/images/bagel_splash_cat.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.45),
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.pets,
                      size: 72,
                      color: PawPartyColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Bagel\'s',
                style: GoogleFonts.fredoka(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: PawPartyColors.primary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: PawPartyColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
