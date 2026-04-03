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

  /// Apply saved avatar/gallery/location on top of [base] (session email/name win).
  static Future<UserProfile> mergeWithSaved(
    UserProfile base,
  ) async {
    final saved = await load(base.id);
    if (saved == null) return base;
    return saved.copyWithProfile(
      email: base.email,
      displayName: base.displayName,
    );
  }
}
