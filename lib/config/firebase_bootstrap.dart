import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

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
    debugPrint('Firebase ready');
  } catch (e, st) {
    debugPrint('Firebase bootstrap failed: $e');
    debugPrint('$st');
  }
}

bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
