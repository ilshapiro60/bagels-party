import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/neighborhood_news.dart';
import '../models/user_profile.dart';

class FirestoreNeighborhoodNewsRepository {
  FirestoreNeighborhoodNewsRepository._();

  static final _db = FirebaseFirestore.instance;
  static const _posts = 'neighborhoodNewsPosts';
  static const _reports = 'neighborhoodNewsReports';

  /// Visible posts for the last [retentionDays].
  static Stream<List<NeighborhoodNewsPost>> watchPostsForArea({
    required String areaKey,
    int retentionDays = 30,
  }) {
    if (areaKey.isEmpty) {
      return Stream.value([]);
    }
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    return _db
        .collection(_posts)
        .where('areaKey', isEqualTo: areaKey)
        .where('hidden', isEqualTo: false)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(NeighborhoodNewsPost.fromDoc).toList());
  }

  static Future<void> createPost({
    required UserProfile author,
    required String title,
    required String body,
    String category = 'general',
    List<String> photoUrls = const [],
    List<String> videoUrls = const [],
  }) async {
    final areaKey = UserProfile.normalizeAreaKey(author.neighborhood);
    if (areaKey.isEmpty) {
      throw StateError('Set your neighborhood in Profile to post.');
    }
    final t = title.trim();
    final b = body.trim();
    if (b.isEmpty && photoUrls.isEmpty && videoUrls.isEmpty) {
      throw StateError('Add a message or at least one photo or video.');
    }
    if (t.length > 140) throw StateError('Title is too long.');
    if (b.length > 2000) throw StateError('Post is too long (max 2000 characters).');
    if (photoUrls.length > 5) throw StateError('Maximum 5 photos per post.');
    if (videoUrls.length > 3) throw StateError('Maximum 3 videos per post.');

    await _db.collection(_posts).add({
      'areaKey': areaKey,
      'authorId': author.id,
      'authorDisplayName': author.displayName.trim().isEmpty
          ? 'Member'
          : author.displayName.trim(),
      'authorPhotoUrl': author.photoUrl,
      'title': t.isEmpty ? null : t,
      'body': b,
      'category': category,
      'photoUrls': photoUrls,
      'videoUrls': videoUrls,
      'hidden': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deletePost(String postId) async {
    await _db.collection(_posts).doc(postId).delete();
  }

  static Future<void> hidePostAsModerator(String postId) async {
    await _db.collection(_posts).doc(postId).update({
      'hidden': true,
      'moderatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<NeighborhoodNewsComment>> watchComments(String postId) {
    return _db
        .collection(_posts)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => NeighborhoodNewsComment.fromDoc(d, postId))
              .toList(),
        );
  }

  static Future<void> addComment({
    required String postId,
    required UserProfile author,
    required String body,
  }) {
    final b = body.trim();
    if (b.isEmpty) throw StateError('Comment cannot be empty.');
    if (b.length > 1000) throw StateError('Comment too long.');
    return _db.collection(_posts).doc(postId).collection('comments').add({
      'authorId': author.id,
      'authorDisplayName': author.displayName.trim().isEmpty
          ? 'Member'
          : author.displayName.trim(),
      'body': b,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _db
        .collection(_posts)
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  static Future<void> submitReport({
    required UserProfile reporter,
    required String postId,
    required String areaKey,
    required String reason,
    String? postTitleSnippet,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) throw StateError('Please describe the issue.');
    if (r.length > 500) throw StateError('Reason too long.');
    await _db.collection(_reports).add({
      'postId': postId,
      'areaKey': areaKey,
      'reporterId': reporter.id,
      'reason': r,
      'status': NeighborhoodNewsReport.statusPending,
      'postTitleSnippet': postTitleSnippet,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<NeighborhoodNewsReport>> watchPendingReports() {
    return _db
        .collection(_reports)
        .where('status', isEqualTo: NeighborhoodNewsReport.statusPending)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(NeighborhoodNewsReport.fromDoc).toList());
  }

  static Future<void> resolveReport({
    required String reportId,
    required bool removePost,
    required String postId,
  }) async {
    final batch = _db.batch();
    final repRef = _db.collection(_reports).doc(reportId);
    batch.update(repRef, {
      'status': removePost
          ? NeighborhoodNewsReport.statusActionTaken
          : NeighborhoodNewsReport.statusDismissed,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    if (removePost) {
      batch.update(_db.collection(_posts).doc(postId), {
        'hidden': true,
        'moderatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
