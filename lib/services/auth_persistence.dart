import 'package:shared_preferences/shared_preferences.dart';

/// Persists last known display name / method for UI; session is restored from
/// [FirebaseAuth] when the app starts.
class AuthPersistence {
  AuthPersistence._();

  static const _kSignedIn = 'pawparty_signed_in';
  static const _kEmail = 'pawparty_email';
  static const _kDisplayName = 'pawparty_display_name';
  static const _kAuthMethod = 'pawparty_auth_method';

  static Future<void> saveSession({
    required String email,
    required String displayName,
    String authMethod = 'email',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSignedIn, true);
    await p.setString(_kEmail, email);
    await p.setString(_kDisplayName, displayName);
    await p.setString(_kAuthMethod, authMethod);
  }

  static Future<({String email, String displayName, String authMethod})?> loadSession() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kSignedIn) != true) return null;
    final email = p.getString(_kEmail);
    final name = p.getString(_kDisplayName);
    if (email == null || name == null) return null;
    final method = p.getString(_kAuthMethod) ?? 'email';
    return (email: email, displayName: name, authMethod: method);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSignedIn);
    await p.remove(_kEmail);
    await p.remove(_kDisplayName);
    await p.remove(_kAuthMethod);
  }
}
