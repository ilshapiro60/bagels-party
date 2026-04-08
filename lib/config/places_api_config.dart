import 'package:flutter/foundation.dart';

/// The native Places SDK uses the same API key as Maps on each platform
/// (AndroidManifest `com.google.android.geo.API_KEY` / iOS Info.plist `GMSApiKey`).
/// No separate `--dart-define` is needed.
///
/// **Google Cloud Console setup (same project as Maps):**
/// 1. Enable **Places API (New)**.
/// 2. On each API key that will be used, add **Places API (New)** to the
///    allowed APIs (alongside Maps SDK for Android / Maps SDK for iOS).
///
/// The native SDK is available on Android and iOS only.
bool get isNativePlacesAvailable =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
