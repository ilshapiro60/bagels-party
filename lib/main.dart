import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';
import 'config/firebase_bootstrap.dart';
import 'config/stripe_config.dart';
import 'config/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();

  // Request ATT on iOS 14+ before initialising ads.
  if (Platform.isIOS) {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT request failed (non-fatal): $e');
    }
  }

  try {
    await MobileAds.instance.initialize();
  } catch (e, st) {
    debugPrint('MobileAds init failed (non-fatal): $e\n$st');
  }

  Stripe.publishableKey = StripeConfig.publishableKey;
  Stripe.merchantIdentifier = StripeConfig.appleMerchantId;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: PawPartyColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: PawPartyApp(),
    ),
  );
}
