import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet.dart';
import '../models/user_profile.dart';

class FirestorePetRepository {
  FirestorePetRepository._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _petsCol(String uid) =>
      _db.collection('profiles').doc(uid).collection('pets');

  /// Only values other devices can load (not device-local cache paths).
  static bool isShareableMediaUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final u = url.trim();
    return u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('gs://');
  }

  static void _sanitizeMediaFieldsInMap(Map<String, dynamic> m) {
    if (!isShareableMediaUrl(m['photoUrl'] as String?)) {
      m['photoUrl'] = null;
    }
    final pg = m['photoGallery'];
    if (pg is List) {
      m['photoGallery'] = pg
          .whereType<String>()
          .where(isShareableMediaUrl)
          .toList();
    }
    final vp = m['videoPaths'];
    if (vp is List) {
      m['videoPaths'] = vp
          .whereType<String>()
          .where(isShareableMediaUrl)
          .toList();
    }
  }

  static String _petCreatedIso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static Pet petFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['createdAt'] = _petCreatedIso(m['createdAt']);
    final parent = snap.reference.parent.parent;
    final oid = m['ownerId'];
    final ownerIdMissing =
        oid == null || (oid is String && oid.trim().isEmpty);
    if (ownerIdMissing && parent != null) {
      m['ownerId'] = parent.id;
    }
    _sanitizeMediaFieldsInMap(m);
    return Pet.fromMap(m);
  }

  static Map<String, dynamic> petToFirestore(Pet p) {
    final m = p.toMap();
    _sanitizeMediaFieldsInMap(m);
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
