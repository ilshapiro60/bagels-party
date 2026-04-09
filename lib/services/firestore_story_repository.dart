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

  static List<PartyStory> _sortNewest(List<PartyStory> list) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Stories by a single author, newest first (for "My stories" screen).
  static Stream<List<PartyStory>> watchStoriesByAuthor(String authorId) {
    return _stories
        .where('authorId', isEqualTo: authorId)
        .snapshots()
        .map((snap) => _sortNewest(snap.docs.map(_fromSnapshot).toList()));
  }

  /// Stories linked to a specific meetup.
  static Stream<List<PartyStory>> watchStoriesForMeetup(String meetupId) {
    return _stories
        .where('meetupId', isEqualTo: meetupId)
        .snapshots()
        .map((snap) => _sortNewest(snap.docs.map(_fromSnapshot).toList()));
  }

  /// Community stories from the last 30 days, newest first.
  static Stream<List<PartyStory>> watchCommunityStories() {
    return _stories
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      return snap.docs
          .map(_fromSnapshot)
          .where((s) => s.createdAt.isAfter(cutoff))
          .toList();
    });
  }
}
