import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSafetyReport {
  const ChatSafetyReport({
    required this.id,
    required this.conversationId,
    required this.reportedUid,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.contextSnippet,
  });

  final String id;
  final String conversationId;
  final String reportedUid;
  final String reporterId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? contextSnippet;

  static const String statusPending = 'pending';
  static const String statusDismissed = 'dismissed';
  static const String statusActionTaken = 'action_taken';

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory ChatSafetyReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return ChatSafetyReport(
      id: doc.id,
      conversationId: m['conversationId'] as String? ?? '',
      reportedUid: m['reportedUid'] as String? ?? '',
      reporterId: m['reporterId'] as String? ?? '',
      reason: m['reason'] as String? ?? '',
      status: m['status'] as String? ?? statusPending,
      createdAt: _ts(m['createdAt']),
      contextSnippet: m['contextSnippet'] as String?,
    );
  }
}
