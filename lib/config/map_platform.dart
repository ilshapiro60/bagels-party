import 'package:flutter/foundation.dart';

/// Google Maps is supported on mobile and web targets only.
bool get mapsPlatformSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
