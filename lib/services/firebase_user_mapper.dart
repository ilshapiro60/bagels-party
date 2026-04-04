import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/user_profile.dart';

/// Maps a signed-in Firebase user into a [UserProfile] shell; app-specific
/// stats and lists default until [ProfilePersistence.mergeWithSaved] runs.
UserProfile userProfileFromFirebaseUser(firebase_auth.User u) {
  final email = u.email ?? '';
  final derivedName = email.isNotEmpty ? email.split('@').first : '';
  final displayName = (u.displayName != null && u.displayName!.trim().isNotEmpty)
      ? u.displayName!.trim()
      : (derivedName.isNotEmpty ? derivedName : 'Member');
  final safeEmail =
      email.isNotEmpty ? email : '${u.uid}@users.noreply.firebase.google.com';
  final created = u.metadata.creationTime ?? DateTime.now();
  return UserProfile(
    id: u.uid,
    email: safeEmail,
    displayName: displayName,
    photoUrl: u.photoURL,
    friendUids: const [],
    createdAt: created,
  );
}
