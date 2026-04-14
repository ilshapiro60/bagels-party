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
