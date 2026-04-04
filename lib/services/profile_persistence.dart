import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Persists profile fields (photo, galleries, map coords) across app restarts.
class ProfilePersistence {
  ProfilePersistence._();

  static String _key(String userId) => 'pawparty_user_profile_$userId';

  static Future<void> save(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(user.id), jsonEncode(user.toMap()));
  }

  static Future<UserProfile?> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return null;
      return UserProfile.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Apply saved device-only fields on top of [base]. Firestore / Auth are
  /// authoritative for identity, [petIds], friends, and stats — the old
  /// implementation reused the entire cached profile (only swapping email
  /// and displayName), which could leak another user's pets or photos if prefs
  /// were stale or the stored JSON did not match the signed-in UID.
  static Future<UserProfile> mergeWithSaved(UserProfile base) async {
    final saved = await load(base.id);
    if (saved == null) return base;
    final savedEmail = saved.email.trim().toLowerCase();
    final baseEmail = base.email.trim().toLowerCase();
    if (savedEmail.isNotEmpty &&
        baseEmail.isNotEmpty &&
        savedEmail != baseEmail) {
      return base;
    }
    final photo = (saved.photoUrl != null && saved.photoUrl!.isNotEmpty)
        ? saved.photoUrl
        : base.photoUrl;
    final hood = (saved.neighborhood != null && saved.neighborhood!.isNotEmpty)
        ? saved.neighborhood
        : base.neighborhood;
    var merged = base.copyWithProfile(
      photoUrl: photo,
      ownerGalleryImagePaths: saved.ownerGalleryImagePaths.isNotEmpty
          ? saved.ownerGalleryImagePaths
          : null,
      ownerGalleryVideoPaths: saved.ownerGalleryVideoPaths.isNotEmpty
          ? saved.ownerGalleryVideoPaths
          : null,
      neighborhood: hood,
    );
    if (saved.latitude != null && saved.longitude != null) {
      merged = merged.copyWithCoordinates(
        latitude: saved.latitude!,
        longitude: saved.longitude!,
        neighborhood: hood ?? merged.neighborhood,
      );
    }
    return merged;
  }
}
