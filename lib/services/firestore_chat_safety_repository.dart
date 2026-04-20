import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_safety_report.dart';
import '../models/user_profile.dart';

class FirestoreChatSafetyRepository {
  FirestoreChatSafetyRepository._();

  static final _db = FirebaseFirestore.instance;
  static const _reports = 'chatSafetyReports';

  static Future<void> submitReport({
    required UserProfile reporter,
    required String conversationId,
    required String reportedUid,
    required String reason,
    String? contextSnippet,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) throw StateError('Please describe the issue.');
    if (r.length > 500) throw StateError('Reason too long.');
    final snippet = contextSnippet?.trim() ?? '';
    if (snippet.length > 200) throw StateError('Context is too long.');
    await _db.collection(_reports).add({
      'conversationId': conversationId,
      'reportedUid': reportedUid,
      'reporterId': reporter.id,
      'reason': r,
      'status': ChatSafetyReport.statusPending,
      if (snippet.isNotEmpty) 'contextSnippet': snippet,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<ChatSafetyReport>> watchPendingReports() {
    return _db
        .collection(_reports)
        .where('status', isEqualTo: ChatSafetyReport.statusPending)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ChatSafetyReport.fromDoc).toList());
  }

  /// Report a user from outside a chat (profile or post context).
  static Future<void> submitProfileReport({
    required String reporterId,
    required String reportedUid,
    required String reason,
    String reportContext = 'profile', // 'profile' | 'post'
    String? contextId,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) throw StateError('Please describe the issue.');
    await _db.collection(_reports).add({
      'conversationId': '',
      'reportedUid': reportedUid,
      'reporterId': reporterId,
      'reason': r,
      'reportContext': reportContext,
      'contextId': ?contextId,
      'status': ChatSafetyReport.statusPending,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> resolveReport({
    required String reportId,
    required bool acknowledge,
  }) async {
    await _db.collection(_reports).doc(reportId).update({
      'status': acknowledge
          ? ChatSafetyReport.statusActionTaken
          : ChatSafetyReport.statusDismissed,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}
