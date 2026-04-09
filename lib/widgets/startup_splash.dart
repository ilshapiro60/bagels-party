import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';

/// Shown while auth session restores.
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
                    alignment: Alignment.center,
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
                'Welcome!',
                style: GoogleFonts.getFont(
                  'TikTok Sans',
                  fontSize: 36,
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
