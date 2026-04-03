import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Initializes Firebase and signs in anonymously so Storage rules can use
/// [request.auth.uid]. No-op when [DefaultFirebaseOptions.isConfigured] is false.
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
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    debugPrint('Firebase ready (anonymous uid: ${FirebaseAuth.instance.currentUser?.uid})');
  } catch (e, st) {
    debugPrint('Firebase bootstrap failed: $e');
    debugPrint('$st');
  }
}

bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
