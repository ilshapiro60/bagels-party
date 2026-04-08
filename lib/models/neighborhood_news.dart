import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared area newsletter post (2-week retention enforced by query + optional TTL).
class NeighborhoodNewsPost {
  const NeighborhoodNewsPost({
    required this.id,
    required this.areaKey,
    required this.authorId,
    required this.authorDisplayName,
    this.authorPhotoUrl,
    this.title,
    required this.body,
    required this.createdAt,
    this.hidden = false,
  });

  final String id;
  final String areaKey;
  final String authorId;
  final String authorDisplayName;
  final String? authorPhotoUrl;
  final String? title;
  final String body;
  final DateTime createdAt;
  final bool hidden;

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory NeighborhoodNewsPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return NeighborhoodNewsPost(
      id: doc.id,
      areaKey: m['areaKey'] as String? ?? '',
      authorId: m['authorId'] as String? ?? '',
      authorDisplayName: m['authorDisplayName'] as String? ?? 'Member',
      authorPhotoUrl: m['authorPhotoUrl'] as String?,
      title: m['title'] as String?,
      body: m['body'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
      hidden: m['hidden'] as bool? ?? false,
    );
  }
}

class NeighborhoodNewsComment {
  const NeighborhoodNewsComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final DateTime createdAt;

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory NeighborhoodNewsComment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String postId,
  ) {
    final m = doc.data() ?? {};
    return NeighborhoodNewsComment(
      id: doc.id,
      postId: postId,
      authorId: m['authorId'] as String? ?? '',
      authorDisplayName: m['authorDisplayName'] as String? ?? 'Member',
      body: m['body'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
    );
  }
}

class NeighborhoodNewsReport {
  const NeighborhoodNewsReport({
    required this.id,
    required this.postId,
    required this.areaKey,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.postTitleSnippet,
  });

  final String id;
  final String postId;
  final String areaKey;
  final String reporterId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? postTitleSnippet;

  static const String statusPending = 'pending';
  static const String statusDismissed = 'dismissed';
  static const String statusActionTaken = 'action_taken';

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory NeighborhoodNewsReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return NeighborhoodNewsReport(
      id: doc.id,
      postId: m['postId'] as String? ?? '',
      areaKey: m['areaKey'] as String? ?? '',
      reporterId: m['reporterId'] as String? ?? '',
      reason: m['reason'] as String? ?? '',
      status: m['status'] as String? ?? statusPending,
      createdAt: _ts(m['createdAt']),
      postTitleSnippet: m['postTitleSnippet'] as String?,
    );
  }
}
