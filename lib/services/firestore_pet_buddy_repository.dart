import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_buddy_request.dart';

/// Accepted pairs live in `petBuddies`. New links go through `petBuddyRequests`
/// until the other pet parent accepts or declines.
class FirestorePetBuddyRepository {
  FirestorePetBuddyRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _buddies =>
      _db.collection('petBuddies');
  static CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('petBuddyRequests');

  static String pairDocId(String petIdA, String petIdB) {
    final sorted = [petIdA, petIdB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static PetBuddyRequest _requestFromDoc(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    return PetBuddyRequest.fromFirestore(snap.id, snap.data() ?? {});
  }

  /// Emits `[]` immediately so listeners are not stuck in [AsyncLoading] while
  /// waiting for the first snapshot (slow offline, rules, or missing index).
  static Stream<List<PetBuddyRequest>> watchIncomingPending(String toOwnerId) async* {
    yield const <PetBuddyRequest>[];
    yield* _requests
        .where('toOwnerId', isEqualTo: toOwnerId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(_requestFromDoc).toList());
  }

  static Stream<List<PetBuddyRequest>> watchOutgoingPending(String fromOwnerId) async* {
    yield const <PetBuddyRequest>[];
    yield* _requests
        .where('fromOwnerId', isEqualTo: fromOwnerId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(_requestFromDoc).toList());
  }

  /// Skips if an identical pending request already exists.
  static Future<void> sendBuddyRequest({
    required String fromUid,
    required String fromPetId,
    required String toPetId,
    required String toOwnerId,
  }) async {
    if (fromPetId == toPetId) return;
    final existing = await _requests
        .where('fromOwnerId', isEqualTo: fromUid)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final d in existing.docs) {
      final m = d.data();
      if (m['fromPetId'] == fromPetId && m['toPetId'] == toPetId) return;
    }
    await _requests.add({
      'fromPetId': fromPetId,
      'fromOwnerId': fromUid,
      'toPetId': toPetId,
      'toOwnerId': toOwnerId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> acceptRequest({
    required String requestId,
    required String actingUid,
  }) async {
    final reqRef = _requests.doc(requestId);
    final snap = await reqRef.get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Request not found');
    }
    final data = snap.data()!;
    if (data['toOwnerId'] != actingUid) throw StateError('Not authorized');
    if (data['status'] != 'pending') throw StateError('Already handled');

    final fromPetId = data['fromPetId'] as String;
    final toPetId = data['toPetId'] as String;
    final fromOwnerId = data['fromOwnerId'] as String;
    final toOwnerId = data['toOwnerId'] as String;

    final sorted = [fromPetId, toPetId]..sort();
    final ownerIds =
        sorted.map((pid) => pid == fromPetId ? fromOwnerId : toOwnerId).toList();
    final buddyDocId = '${sorted[0]}_${sorted[1]}';

    final batch = _db.batch();
    batch.update(reqRef, {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_buddies.doc(buddyDocId), {
      'petIds': sorted,
      'ownerIds': ownerIds,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> declineRequest({
    required String requestId,
    required String actingUid,
  }) async {
    final reqRef = _requests.doc(requestId);
    final snap = await reqRef.get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Request not found');
    }
    final data = snap.data()!;
    if (data['toOwnerId'] != actingUid) throw StateError('Not authorized');
    if (data['status'] != 'pending') return;
    await reqRef.update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> cancelOutgoingRequest({
    required String requestId,
    required String actingUid,
  }) async {
    final reqRef = _requests.doc(requestId);
    final snap = await reqRef.get();
    if (!snap.exists || snap.data() == null) return;
    final data = snap.data()!;
    if (data['fromOwnerId'] != actingUid) throw StateError('Not authorized');
    if (data['status'] != 'pending') return;
    await reqRef.delete();
  }

  static Future<bool> areBuddies(String petIdA, String petIdB) async {
    if (petIdA == petIdB) return false;
    final snap = await _buddies.doc(pairDocId(petIdA, petIdB)).get();
    return snap.exists;
  }

  static Future<void> removeBuddy(String petIdA, String petIdB) async {
    await _buddies.doc(pairDocId(petIdA, petIdB)).delete();
  }

  static Stream<List<({String otherPetId, String otherOwnerId})>> watchEdgesForPet(
    String petId,
  ) {
    return _buddies
        .where('petIds', arrayContains: petId)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        final ids = List<String>.from(data['petIds'] as List? ?? []);
        final owners = List<String>.from(data['ownerIds'] as List? ?? []);
        if (ids.length != 2 || owners.length != 2) {
          return (otherPetId: '', otherOwnerId: '');
        }
        final i = ids.indexOf(petId);
        if (i < 0) return (otherPetId: '', otherOwnerId: '');
        final j = 1 - i;
        return (otherPetId: ids[j], otherOwnerId: owners[j]);
      }).where((e) => e.otherPetId.isNotEmpty).toList();
    });
  }
}
