import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// On sideloaded **release** APKs, Play Integrity often returns
/// `App attestation failed` until the app is distributed through Play with
/// proper Firebase linkage. Use
/// `--dart-define=FORCE_APP_CHECK_DEBUG=true` and a registered debug token.
const bool _forceAppCheckDebug =
    bool.fromEnvironment('FORCE_APP_CHECK_DEBUG', defaultValue: false);

bool get _useProductionAppCheckAttestation =>
    kReleaseMode && !_forceAppCheckDebug;

/// Initializes Firebase. Storage and other services use [FirebaseAuth] after
/// the user signs in (e.g. Google). No-op when [DefaultFirebaseOptions.isConfigured]
/// is false.
Future<void> bootstrapFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'Firebase skipped: run `flutterfire configure` to generate firebase_options.dart',
    );
    return;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await _activateAppCheckIfNeeded();
    debugPrint('Firebase ready');
  } catch (e, st) {
    debugPrint('Firebase bootstrap failed: $e');
    debugPrint('$st');
  }
}

/// When App Check is enforced for Cloud Storage, uploads fail (often 404 /
/// object-not-found on resumable upload) unless a provider is registered.
///
/// **Debug / profile / unreleased release+define:** [AndroidDebugProvider] /
/// [AppleDebugProvider] — register the device token in Firebase Console →
/// App Check → Manage debug tokens (logcat / Xcode).
///
/// **Store release builds:** Play Integrity (Android) and App Attest fallback (iOS).
///
/// **Web:** configure ReCAPTCHA per Firebase web docs; native [activate] is skipped here.
Future<void> _activateAppCheckIfNeeded() async {
  if (Firebase.apps.isEmpty) return;
  if (kIsWeb) {
    return;
  }
  try {
    // Android debug/profile: [AppCheckEarlyInitProvider] (initOrder 101) registers
    // the debug factory before [FirebaseInitProvider] (100). Do not call
    // [FirebaseAppCheck.activate] here — it can replace the provider and break Auth.
    // Release (+ optional FORCE_APP_CHECK_DEBUG) has no early provider — use Dart [activate].
    if (defaultTargetPlatform == TargetPlatform.android && !kReleaseMode) {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      debugPrint(
        'App Check: Android debug via AppCheckEarlyInitProvider — register the '
        'token from logcat in Firebase Console → App Check.',
      );
      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: _useProductionAppCheckAttestation
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: _useProductionAppCheckAttestation
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    if (!_useProductionAppCheckAttestation) {
      debugPrint(
        'App Check: debug provider — copy the debug token from logcat (Android) '
        'or Xcode (iOS) into Firebase Console → App Check → Manage debug tokens.',
      );
    }
  } catch (e, st) {
    debugPrint('App Check activation failed (Storage may break if enforced): $e');
    debugPrint('$st');
  }
}

bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
