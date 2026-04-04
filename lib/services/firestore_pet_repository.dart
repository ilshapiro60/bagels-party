import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet.dart';
import '../models/user_profile.dart';

class FirestorePetRepository {
  FirestorePetRepository._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _petsCol(String uid) =>
      _db.collection('profiles').doc(uid).collection('pets');

  static String _petCreatedIso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static Pet petFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['createdAt'] = _petCreatedIso(m['createdAt']);
    return Pet.fromMap(m);
  }

  static Map<String, dynamic> petToFirestore(Pet p) {
    final m = p.toMap();
    m['createdAt'] = Timestamp.fromDate(p.createdAt);
    return m;
  }

  static Future<List<Pet>> loadForUser(String uid) async {
    final snap = await _petsCol(uid).get();
    return snap.docs.map(petFromSnapshot).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> upsert(String uid, Pet pet) async {
    await _petsCol(uid).doc(pet.id).set(petToFirestore(pet));
  }

  static Future<void> delete(String uid, String petId) async {
    await _petsCol(uid).doc(petId).delete();
  }

  static Future<Pet?> fetchPet(String ownerId, String petId) async {
    final snap = await _petsCol(ownerId).doc(petId).get();
    if (!snap.exists || snap.data() == null) return null;
    return petFromSnapshot(snap);
  }

  /// Denormalize owner location onto the pet doc for Discover map pins.
  static Pet withOwnerAnchor(Pet pet, UserProfile? owner) {
    final lat = owner?.latitude;
    final lng = owner?.longitude;
    if (lat == null || lng == null) return pet;
    return pet.copyWith(ownerApproxLat: lat, ownerApproxLng: lng);
  }

  static Stream<List<Pet>> watchCommunityPets({String? excludeOwnerId}) {
    return _db.collectionGroup('pets').snapshots().map((snap) {
      final list = snap.docs.map(petFromSnapshot).where((p) {
        if (excludeOwnerId == null) return true;
        return p.ownerId != excludeOwnerId;
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
