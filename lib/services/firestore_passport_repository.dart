import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/passport_entry.dart';

class FirestorePassportRepository {
  FirestorePassportRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('passportEntries');

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static PassportEntry entryFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['date'] = _iso(m['date']);
    return PassportEntry.fromMap(m);
  }

  /// Entries for this owner, newest party date first.
  static Stream<List<PassportEntry>> watchMyEntries(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(entryFromSnapshot).toList());
  }

  /// Public journal posts for the Community tab.
  static Stream<List<PassportEntry>> watchPublicEntries({int limit = 100}) {
    return _col
        .where('isPublic', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(entryFromSnapshot).toList());
  }

  static Map<String, dynamic> _toWrite(PassportEntry e, {bool isCreate = false}) {
    final map = e.toFirestoreMap();
    map['date'] = Timestamp.fromDate(e.date);
    if (isCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  static Future<void> upsertEntry(PassportEntry entry, {bool isCreate = false}) async {
    await _col.doc(entry.id).set(_toWrite(entry, isCreate: isCreate), SetOptions(merge: true));
  }

  static Future<void> deleteEntry({
    required String entryId,
    required String actingOwnerId,
  }) async {
    final ref = _col.doc(entryId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null || data['ownerId'] != actingOwnerId) {
      throw StateError('Only the owner can delete this entry.');
    }
    await ref.delete();
  }

  static Future<List<PassportEntry>> fetchOwnerEntriesForMeetup({
    required String ownerId,
    required String meetupId,
  }) async {
    final q = await _col
        .where('ownerId', isEqualTo: ownerId)
        .where('meetupId', isEqualTo: meetupId)
        .get();
    return q.docs.map(entryFromSnapshot).toList();
  }

  static Future<void> deleteEntriesForMeetup({
    required String ownerId,
    required String meetupId,
  }) async {
    final q = await _col
        .where('ownerId', isEqualTo: ownerId)
        .where('meetupId', isEqualTo: meetupId)
        .get();
    final batch = _db.batch();
    for (final d in q.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
