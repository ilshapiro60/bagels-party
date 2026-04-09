import 'package:cloud_firestore/cloud_firestore.dart';

/// A comment on a public passport journal entry.
class JournalComment {
  final String id;
  final String entryId;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final DateTime createdAt;

  const JournalComment({
    required this.id,
    required this.entryId,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.createdAt,
  });

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory JournalComment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String entryId,
  ) {
    final m = doc.data() ?? {};
    return JournalComment(
      id: doc.id,
      entryId: entryId,
      authorId: m['authorId'] as String? ?? '',
      authorDisplayName: m['authorDisplayName'] as String? ?? 'Member',
      body: m['body'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
    );
  }
}
