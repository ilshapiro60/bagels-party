import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_auth_config.dart';

bool _googleSignInInitialized = false;

/// All callers await the same future so two parallel paths (e.g. session
/// restore + user taps Google) never call [GoogleSignIn.initialize] twice.
Future<void>? _googleSignInInitInFlight;

/// [GoogleSignIn] 7.x requires a one-time [GoogleSignIn.initialize] before use.
Future<void> ensureGoogleSignInInitialized() async {
  if (_googleSignInInitialized) return;
  _googleSignInInitInFlight ??= _runGoogleSignInInit();
  await _googleSignInInitInFlight!;
}

Future<void> _runGoogleSignInInit() async {
  try {
    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: kGoogleWebClientId,
      );
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId: kGoogleWebClientId,
      );
    }
    _googleSignInInitialized = true;
  } catch (e) {
    _googleSignInInitInFlight = null;
    rethrow;
  }
}
