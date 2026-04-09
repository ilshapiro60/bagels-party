import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/user_profile.dart';
import 'firebase_user_mapper.dart';
import 'firestore_message_repository.dart';
import 'firestore_pet_repository.dart';

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
    m['neighborhoodKey'] = UserProfile.normalizeAreaKey(u.neighborhood);
    m['isModerator'] = u.isModerator;
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

  /// Profile fields visible to other users: only http/https/gs media URLs.
  /// Local device paths are stripped so neighbors do not get broken images.
  static UserProfile profileForCloudWrite(UserProfile u) {
    final okPhoto = FirestorePetRepository.isShareableMediaUrl(u.photoUrl);
    return UserProfile(
      id: u.id,
      email: u.email,
      displayName: u.displayName,
      photoUrl: okPhoto ? u.photoUrl : null,
      ownerGalleryImagePaths: u.ownerGalleryImagePaths
          .where(FirestorePetRepository.isShareableMediaUrl)
          .toList(),
      ownerGalleryVideoPaths: u.ownerGalleryVideoPaths
          .where(FirestorePetRepository.isShareableMediaUrl)
          .toList(),
      neighborhood: u.neighborhood,
      neighborhoodKey: u.neighborhoodKey,
      isModerator: u.isModerator,
      latitude: u.latitude,
      longitude: u.longitude,
      petIds: u.petIds,
      friendUids: u.friendUids,
      childAges: u.childAges,
      hostCount: u.hostCount,
      attendCount: u.attendCount,
      hostRating: u.hostRating,
      guestRating: u.guestRating,
      isHostPassActive: u.isHostPassActive,
      hostPassExpiry: u.hostPassExpiry,
      createdAt: u.createdAt,
      bio: u.bio,
    );
  }

  static Future<void> saveProfile(UserProfile u) async {
    final forCloud = profileForCloudWrite(u);
    final m = profileToFirestore(forCloud);
    if (!FirestorePetRepository.isShareableMediaUrl(u.photoUrl)) {
      m['photoUrl'] = FieldValue.delete();
    }
    await _profiles.doc(u.id).set(m, SetOptions(merge: true));
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
      data['neighborhoodKey'] = UserProfile.normalizeAreaKey(neighborhood);
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

  /// Removes [friendUid] from both users' friendUids arrays.
  static Future<void> removeFriend({
    required String uid,
    required String friendUid,
  }) async {
    final batch = _db.batch();
    batch.set(
      _profiles.doc(uid),
      {'friendUids': FieldValue.arrayRemove([friendUid])},
      SetOptions(merge: true),
    );
    batch.set(
      _profiles.doc(friendUid),
      {'friendUids': FieldValue.arrayRemove([uid])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Broadcast a shout message to all friends via DMs.
  static Future<void> broadcastShout({
    required String fromUid,
    required String fromName,
    required List<String> friendUids,
    required String message,
  }) async {
    for (final friendUid in friendUids) {
      final convId =
          await FirestoreMessageRepository.ensureConversation(fromUid, friendUid);
      await FirestoreMessageRepository.sendMessage(
        conversationId: convId,
        fromUid: fromUid,
        body: message,
        isShout: true,
      );
    }
  }
}
