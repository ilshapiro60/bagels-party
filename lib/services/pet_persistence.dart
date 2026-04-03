import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet.dart';
import 'mock_data.dart';

/// Saves each user's pet list locally so adds/edits survive app restarts.
class PetPersistence {
  PetPersistence._();

  static String _key(String userId) => 'pawparty_pets_$userId';

  static Future<List<Pet>> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) {
        return MockData.userPets.where((p) => p.ownerId == userId).toList();
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Pet.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return MockData.userPets.where((p) => p.ownerId == userId).toList();
    }
  }

  static Future<void> save(String userId, List<Pet> pets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(pets.map((p) => p.toMap()).toList());
    await prefs.setString(_key(userId), raw);
  }
}
