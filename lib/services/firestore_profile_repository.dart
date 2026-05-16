import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

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
    return UserProfile.fromMap(m);
  }

  static Map<String, dynamic> profileToFirestore(UserProfile u) {
    final m = u.toMap();
    m['createdAt'] = Timestamp.fromDate(u.createdAt);
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
  ///
  /// All non-media fields on [UserProfile] must be forwarded explicitly here —
  /// the rebuilt instance is what gets serialized by [profileToFirestore], so
  /// any field omitted below falls back to the constructor default (e.g.
  /// `isBusinessAccount = false`) and silently wipes the cloud copy on save.
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
      blockedUids: u.blockedUids,
      hostCount: u.hostCount,
      attendCount: u.attendCount,
      hostRating: u.hostRating,
      guestRating: u.guestRating,
      createdAt: u.createdAt,
      bio: u.bio,
      isBusinessAccount: u.isBusinessAccount,
      businessName: u.businessName,
      businessCategory: u.businessCategory,
      businessPlaceId: u.businessPlaceId,
      isCheckedIn: u.isCheckedIn,
      termsAccepted: u.termsAccepted,
    );
  }

  /// Stream of user IDs who are currently checked in (visible on the map).
  static Stream<Set<String>> watchCheckedInUserIds() {
    return _profiles
        .where('isCheckedIn', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  static Future<void> saveProfile(UserProfile u) async {
    final forCloud = profileForCloudWrite(u);
    final m = profileToFirestore(forCloud);
    if (!FirestorePetRepository.isShareableMediaUrl(u.photoUrl)) {
      m['photoUrl'] = FieldValue.delete();
    }
    m['childAges'] = FieldValue.delete();
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

  /// Drops [friendUids] entries whose `profiles/{id}` no longer exists (e.g.
  /// after the other user deleted their account but cleanup missed a uid).
  static Future<void> pruneStaleFriendUids(String uid) async {
    final snap = await _profiles.doc(uid).get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    final raw = data['friendUids'];
    if (raw is! List) return;
    final friendUids = raw
        .map((e) => e is String ? e : e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (friendUids.isEmpty) return;
    final stale = <String>[];
    for (final fid in friendUids) {
      if (fid == uid) continue;
      final p = await fetchProfile(fid);
      if (p == null) stale.add(fid);
    }
    if (stale.isEmpty) return;
    await _profiles.doc(uid).update({
      'friendUids': FieldValue.arrayRemove(stale),
    });
  }

  /// Removes [friendUid] from both users' friendUids arrays.
  static Future<void> removeFriend({
    required String uid,
    required String friendUid,
  }) async {
    // Own profile: always allowed.
    await _profiles.doc(uid).update({
      'friendUids': FieldValue.arrayRemove([friendUid]),
    });
    // Other user's profile: only succeeds when they had us in their list.
    // Silently ignore permission errors — they may not be mutual friends.
    try {
      await _profiles.doc(friendUid).update({
        'friendUids': FieldValue.arrayRemove([uid]),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
  }

  static Future<void> blockUser({
    required String myUid,
    required String targetUid,
  }) async {
    await _profiles.doc(myUid).update({
      'blockedUids': FieldValue.arrayUnion([targetUid]),
    });
  }

  static Future<void> unblockUser({
    required String myUid,
    required String targetUid,
  }) async {
    await _profiles.doc(myUid).update({
      'blockedUids': FieldValue.arrayRemove([targetUid]),
    });
  }

  /// Broadcast a shout as **one** group conversation with all friends, one message.
  /// The message body starts with friend display names separated by commas, then the text.
  static Future<void> broadcastShout({
    required String fromUid,
    required List<String> friendUids,
    required String message,
  }) async {
    final friends = friendUids.where((id) => id != fromUid).toSet().toList();
    if (friends.isEmpty) return;

    final names = <String>[];
    for (final uid in friends) {
      final p = await fetchProfile(uid);
      final n = p?.displayName.trim();
      names.add(n != null && n.isNotEmpty ? n : 'Friend');
    }
    final recipientsLabel = names.join(', ');
    var body = '$recipientsLabel: ${message.trim()}';
    if (body.length > 2000) {
      body = body.substring(0, 2000);
    }

    String convId;
    try {
      convId = await FirestoreMessageRepository.ensureGroupConversation([
        fromUid,
        ...friends,
      ]);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && friends.length > 1) {
        // Rules in Firebase may still require exactly two participants until you deploy
        // the repo’s firestore.rules (2–20). Same shout body to each 1:1 thread.
        debugPrint(
          'broadcastShout: group conversation denied (${e.code}); '
          'using per-friend DMs. Deploy latest firestore.rules for one group thread.',
        );
        await _broadcastShoutPerFriendDms(
          fromUid: fromUid,
          friendUids: friends,
          body: body,
        );
        return;
      }
      rethrow;
    }

    try {
      await FirestoreMessageRepository.sendMessage(
        conversationId: convId,
        fromUid: fromUid,
        body: body,
        isShout: true,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && friends.length > 1) {
        debugPrint(
          'broadcastShout: group message denied (${e.code}); '
          'using per-friend DMs. Deploy latest firestore.rules.',
        );
        await _broadcastShoutPerFriendDms(
          fromUid: fromUid,
          friendUids: friends,
          body: body,
        );
        return;
      }
      rethrow;
    }
  }

  /// Same [body] to each 1:1 thread (used when group conversation create is denied by rules).
  static Future<void> _broadcastShoutPerFriendDms({
    required String fromUid,
    required List<String> friendUids,
    required String body,
  }) async {
    for (final friendUid in friendUids) {
      final convId =
          await FirestoreMessageRepository.ensureConversation(fromUid, friendUid);
      await FirestoreMessageRepository.sendMessage(
        conversationId: convId,
        fromUid: fromUid,
        body: body,
        isShout: true,
      );
    }
  }
}
