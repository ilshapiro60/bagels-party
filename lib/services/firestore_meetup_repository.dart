import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meetup.dart';
import '../models/party_invite.dart';

class FirestoreMeetupRepository {
  FirestoreMeetupRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _meetups =>
      _db.collection('meetups');

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static Map<String, dynamic> _inviteToFirestore(MeetupInvite i) {
    return {
      'guestId': i.guestId,
      'guestName': i.guestName,
      'petIds': i.petIds,
      'status': i.status.name,
      'sentAt': Timestamp.fromDate(i.sentAt),
    };
  }

  static Map<String, dynamic> meetupToFirestore(Meetup m) {
    return {
      'id': m.id,
      'hostId': m.hostId,
      'hostName': m.hostName,
      'hostPhotoUrl': m.hostPhotoUrl,
      'title': m.title,
      'description': m.description,
      'theme': m.theme,
      'dateTime': Timestamp.fromDate(m.dateTime),
      'durationMinutes': m.durationMinutes,
      'address': m.address,
      'latitude': m.latitude,
      'longitude': m.longitude,
      'maxGuests': m.maxGuests,
      'invites': m.invites.map(_inviteToFirestore).toList(),
      'pizzaCommitment': m.pizzaCommitment.toMap(),
      'status': m.status.name,
      'hasYard': m.hasYard,
      'hasPool': m.hasPool,
      'kidFriendly': m.kidFriendly,
      'compatiblePetIds': m.compatiblePetIds,
      'createdAt': Timestamp.fromDate(m.createdAt),
      'isPublic': m.isPublic,
      'venueName': m.venueName,
      'venuePlaceId': m.venuePlaceId,
    };
  }

  static Meetup meetupFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['dateTime'] = _iso(m['dateTime']);
    m['createdAt'] = _iso(m['createdAt']);
    final invites = m['invites'];
    if (invites is List) {
      m['invites'] = invites.map((raw) {
        final im = Map<String, dynamic>.from(raw as Map);
        im['sentAt'] = _iso(im['sentAt']);
        return im;
      }).toList();
    }
    return Meetup.fromMap(m);
  }

  static Future<void> createMeetup(Meetup meetup) async {
    await _meetups.doc(meetup.id).set(meetupToFirestore(meetup));
  }

  static Future<Meetup?> fetchMeetup(String meetupId) async {
    final snap = await _meetups.doc(meetupId).get();
    if (!snap.exists) return null;
    return meetupFromSnapshot(snap);
  }

  static Future<void> updateMeetup({
    required String meetupId,
    required String actingHostId,
    required String title,
    String? description,
    required DateTime dateTime,
    required int durationMinutes,
  }) async {
    await _meetups.doc(meetupId).update({
      'title': title.trim(),
      'description': description?.trim(),
      'dateTime': Timestamp.fromDate(dateTime),
      'durationMinutes': durationMinutes,
    });
  }

  /// Removes the party document. Only the host may delete ([actingHostId]).
  static Future<void> deleteMeetup({
    required String meetupId,
    required String actingHostId,
  }) async {
    final docRef = _meetups.doc(meetupId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null || data['hostId'] != actingHostId) {
      throw StateError('Only the host can delete this party.');
    }
    await docRef.delete();
  }

  /// Parties hosted by [hostId], newest first (by scheduled time).
  static Stream<List<Meetup>> watchHostedBy(String hostId) {
    return _meetups.where('hostId', isEqualTo: hostId).snapshots().map((snap) {
      final list = snap.docs.map(meetupFromSnapshot).toList();
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    });
  }

  /// All public meetups that are open or full, sorted soonest-first.
  /// Client should filter by distance and future date.
  static Stream<List<Meetup>> watchPublicMeetups() {
    return _meetups
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final list = snap.docs
          .map(meetupFromSnapshot)
          .where((m) =>
              m.dateTime.isAfter(now) &&
              (m.status == MeetupStatus.open || m.status == MeetupStatus.full))
          .toList();
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    });
  }

  /// Self-RSVP to a public meetup (creates a partyInvites doc where guest == host of the doc).
  static Future<void> rsvpToPublicMeetup({
    required String meetupId,
    required String meetupTitle,
    required String hostId,
    required String hostName,
    required String guestId,
    required String guestName,
  }) async {
    final existing = await _partyInvites
        .where('meetupId', isEqualTo: meetupId)
        .where('guestId', isEqualTo: guestId)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _partyInvites.doc().set({
      'meetupId': meetupId,
      'meetupTitle': meetupTitle,
      'hostId': hostId,
      'hostName': hostName,
      'guestId': guestId,
      'guestName': guestName,
      'status': 'accepted',
      'sentAt': FieldValue.serverTimestamp(),
      'respondedAt': FieldValue.serverTimestamp(),
      'selfRsvp': true,
    });
  }

  /// Cancel a self-RSVP (guest deletes their own invite doc).
  static Future<void> cancelRsvp({
    required String meetupId,
    required String actingUid,
  }) async {
    final snap = await _partyInvites
        .where('meetupId', isEqualTo: meetupId)
        .where('guestId', isEqualTo: actingUid)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Party invites (separate collection for clean security rules)
  // ---------------------------------------------------------------------------

  static CollectionReference<Map<String, dynamic>> get _partyInvites =>
      _db.collection('partyInvites');

  static PartyInvite _inviteFromDoc(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    if (m['sentAt'] is Timestamp) {
      m['sentAt'] = (m['sentAt'] as Timestamp).toDate().toIso8601String();
    }
    if (m['respondedAt'] is Timestamp) {
      m['respondedAt'] =
          (m['respondedAt'] as Timestamp).toDate().toIso8601String();
    }
    return PartyInvite.fromFirestore(snap.id, m);
  }

  /// Creates invite documents for each selected friend.
  static Future<void> sendPartyInvites({
    required String meetupId,
    required String meetupTitle,
    required String hostId,
    required String hostName,
    required List<({String uid, String displayName})> guests,
  }) async {
    final batch = _db.batch();
    for (final g in guests) {
      final ref = _partyInvites.doc();
      batch.set(ref, {
        'meetupId': meetupId,
        'meetupTitle': meetupTitle,
        'hostId': hostId,
        'hostName': hostName,
        'guestId': g.uid,
        'guestName': g.displayName,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Invitations the current user has received (pending first, newest first).
  static Stream<List<PartyInvite>> watchIncomingInvites(String guestId) {
    return _partyInvites
        .where('guestId', isEqualTo: guestId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_inviteFromDoc).toList();
      list.sort((a, b) {
        final statusOrder = {
          PartyInviteStatus.pending: 0,
          PartyInviteStatus.accepted: 1,
          PartyInviteStatus.declined: 2,
        };
        final cmp = statusOrder[a.status]!.compareTo(statusOrder[b.status]!);
        if (cmp != 0) return cmp;
        return b.sentAt.compareTo(a.sentAt);
      });
      return list;
    });
  }

  /// Invitations the host sent for this meetup (must filter by [hostId] so
  /// Firestore rules can authorize the list query).
  static Stream<List<PartyInvite>> watchInvitesForMeetupAsHost({
    required String meetupId,
    required String hostId,
  }) {
    return _partyInvites
        .where('meetupId', isEqualTo: meetupId)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .map((snap) => snap.docs.map(_inviteFromDoc).toList());
  }

  /// Guest IDs that already have a pending or accepted invite (for UI filters).
  static Future<Set<String>> guestIdsWithActiveInvite({
    required String meetupId,
    required String hostId,
  }) async {
    final snap = await _partyInvites
        .where('meetupId', isEqualTo: meetupId)
        .where('hostId', isEqualTo: hostId)
        .get();
    final out = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final st = m['status'] as String? ?? '';
      if (st == 'pending' || st == 'accepted') {
        final gid = m['guestId'] as String?;
        if (gid != null) out.add(gid);
      }
    }
    return out;
  }

  /// Host removes an invite (pending, accepted, or declined).
  static Future<void> deletePartyInvite({
    required String inviteId,
    required String actingHostId,
  }) async {
    final docRef = _partyInvites.doc(inviteId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null || data['hostId'] != actingHostId) {
      throw StateError('Only the host can remove this invite.');
    }
    await docRef.delete();
  }

  static Future<void> respondToInvite({
    required String inviteId,
    required String actingUid,
    required PartyInviteStatus response,
  }) async {
    final ref = _partyInvites.doc(inviteId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Invite not found');
    final data = snap.data()!;
    if (data['guestId'] != actingUid) throw StateError('Not authorized');
    await ref.update({
      'status': response.name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }
}
