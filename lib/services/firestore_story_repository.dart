import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/party_story.dart';

class FirestoreStoryRepository {
  FirestoreStoryRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _stories =>
      _db.collection('partyStories');

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static Map<String, dynamic> _toFirestore(PartyStory s) {
    final m = s.toMap();
    m['createdAt'] = Timestamp.fromDate(s.createdAt);
    return m;
  }

  static PartyStory _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = Map<String, dynamic>.from(snap.data() ?? {});
    m['id'] = snap.id;
    m['createdAt'] = _iso(m['createdAt']);
    return PartyStory.fromMap(m);
  }

  static Future<void> createStory(PartyStory story) async {
    await _stories.doc(story.id).set(_toFirestore(story));
  }

  static Future<void> deleteStory({
    required String storyId,
    required String actingUid,
  }) async {
    final ref = _stories.doc(storyId);
    final snap = await ref.get();
    if (!snap.exists) return;
    if (snap.data()?['authorId'] != actingUid) {
      throw StateError('Only the author can delete this story.');
    }
    await ref.delete();
  }

  /// Stories by a single author, newest first (for "My stories" screen).
  static Stream<List<PartyStory>> watchStoriesByAuthor(String authorId) {
    return _stories
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromSnapshot).toList());
  }

  /// Community stories from the last 30 days, newest first.
  /// Client should distance-filter on top.
  static Stream<List<PartyStory>> watchCommunityStories() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _stories
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromSnapshot).toList());
  }
}
