import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_auth_config.dart';

bool _googleSignInInitialized = false;

/// [GoogleSignIn] 7.x requires a one-time [GoogleSignIn.initialize] before use.
Future<void> ensureGoogleSignInInitialized() async {
  if (_googleSignInInitialized) return;
  if (kIsWeb) {
    await GoogleSignIn.instance.initialize();
  } else {
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleWebClientId,
    );
  }
  _googleSignInInitialized = true;
}
