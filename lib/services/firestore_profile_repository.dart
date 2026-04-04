import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/user_profile.dart';
import 'firebase_user_mapper.dart';

class FirestoreProfileRepository {
  FirestoreProfileRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('profiles');

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static UserProfile profileFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['createdAt'] = _iso(m['createdAt']);
    if (m['hostPassExpiry'] != null) {
      m['hostPassExpiry'] = _iso(m['hostPassExpiry']);
    }
    return UserProfile.fromMap(m);
  }

  static Map<String, dynamic> profileToFirestore(UserProfile u) {
    final m = u.toMap();
    m['createdAt'] = Timestamp.fromDate(u.createdAt);
    if (u.hostPassExpiry != null) {
      m['hostPassExpiry'] = Timestamp.fromDate(u.hostPassExpiry!);
    }
    return m;
  }

  static Future<UserProfile?> fetchProfile(String uid) async {
    final snap = await _profiles.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return profileFromSnapshot(snap);
  }

  /// Creates a Firestore profile from [firebase_auth.User] if missing.
  static Future<UserProfile> fetchOrCreate(firebase_auth.User u) async {
    final ref = _profiles.doc(u.uid);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return profileFromSnapshot(snap);
    }
    final initial = userProfileFromFirebaseUser(u);
    await ref.set(profileToFirestore(initial));
    return initial;
  }

  static Future<void> saveProfile(UserProfile u) async {
    await _profiles.doc(u.id).set(profileToFirestore(u), SetOptions(merge: true));
  }

  static Future<void> incrementHostCount(String uid) async {
    await _profiles.doc(uid).set(
      {'hostCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  static Future<void> decrementHostCount(String uid) async {
    await _profiles.doc(uid).set(
      {'hostCount': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
  }

  static Future<void> updateLocation({
    required String uid,
    required double latitude,
    required double longitude,
    String? neighborhood,
  }) async {
    final data = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (neighborhood != null) {
      data['neighborhood'] = neighborhood;
    }
    await _profiles.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Adds the other pet parent for every accepted paw-buddy request (both
  /// directions). The accepter also gets an immediate [friendUids] write in
  /// [FirestorePetBuddyRepository.acceptRequest]; this covers the requester.
  static Future<void> syncFriendsFromAcceptedPetBuddyRequests(String uid) async {
    final asSender = await _db
        .collection('petBuddyRequests')
        .where('fromOwnerId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final asRecipient = await _db
        .collection('petBuddyRequests')
        .where('toOwnerId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    final others = <String>{};
    for (final d in asSender.docs) {
      final to = d.data()['toOwnerId'];
      if (to is String && to.isNotEmpty) others.add(to);
    }
    for (final d in asRecipient.docs) {
      final from = d.data()['fromOwnerId'];
      if (from is String && from.isNotEmpty) others.add(from);
    }
    others.remove(uid);
    if (others.isEmpty) return;
    await _profiles.doc(uid).set(
      {'friendUids': FieldValue.arrayUnion(others.toList())},
      SetOptions(merge: true),
    );
  }
}
