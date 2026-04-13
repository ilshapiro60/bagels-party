import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Region where callable Cloud Functions are deployed.
///
/// Must match the region in Google Cloud (Firebase → Functions). If this
/// does not match, callable requests return `NOT_FOUND` even when the code
/// exists in the repo.
const String kFirebaseCallableRegion = 'us-central1';

FirebaseFunctions pawPartyFirebaseFunctions() {
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase is not initialized.');
  }
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: kFirebaseCallableRegion,
  );
}
