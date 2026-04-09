import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/party_album_item.dart';

class FirestorePartyAlbumRepository {
  FirestorePartyAlbumRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('partyAlbumPhotos');

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static PartyAlbumItem _fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['createdAt'] = _iso(m['createdAt']);
    return PartyAlbumItem.fromMap(m);
  }

  /// All shared album items for a given meetup, newest first.
  static Stream<List<PartyAlbumItem>> watchAlbumForMeetup(String meetupId) {
    return _col
        .where('meetupId', isEqualTo: meetupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromSnapshot).toList());
  }

  static Future<void> addItem(PartyAlbumItem item) async {
    final map = item.toMap();
    map['createdAt'] = Timestamp.fromDate(item.createdAt);
    await _col.doc(item.id).set(map);
  }

  static Future<void> deleteItem({
    required String itemId,
    required String actingUid,
  }) async {
    final ref = _col.doc(itemId);
    final snap = await ref.get();
    if (!snap.exists) return;
    if (snap.data()?['uploaderId'] != actingUid) {
      throw StateError('Only the uploader can delete this photo.');
    }
    await ref.delete();
  }
}
