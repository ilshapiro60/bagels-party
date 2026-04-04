import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meetup.dart';

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

  /// Parties hosted by [hostId], newest first (by scheduled time).
  static Stream<List<Meetup>> watchHostedBy(String hostId) {
    return _meetups.where('hostId', isEqualTo: hostId).snapshots().map((snap) {
      final list = snap.docs.map(meetupFromSnapshot).toList();
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    });
  }
}
