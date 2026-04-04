import 'package:firebase_core/firebase_core.dart';

/// Retries Firestore operations that often succeed on a second attempt (mobile
/// networks, cold starts, regional blips).
Future<T> firestoreRetry<T>(Future<T> Function() action) async {
  const maxAttempts = 4;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } on FirebaseException catch (e) {
      final retryable = e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'resource-exhausted';
      if (!retryable || attempt == maxAttempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 200 * attempt * attempt));
    }
  }
  throw StateError('firestoreRetry: exhausted attempts');
}
