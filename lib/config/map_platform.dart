import 'package:flutter/foundation.dart';

/// Google Maps is supported on mobile and web targets only.
bool get mapsPlatformSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Vet clinic picker uses native Places SDK + embedded Google Map (Android & iOS only).
bool get vetClinicMapPickerSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
