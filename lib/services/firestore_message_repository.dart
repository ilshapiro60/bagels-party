import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/direct_message.dart';

class FirestoreMessageRepository {
  FirestoreMessageRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  /// Messages older than this are not loaded and may be pruned from Firestore.
  static const Duration messageRetention = Duration(days: 30);

  static const int maxMediaUrlsPerMessage = 6;

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
  }

  static Timestamp _retentionCutoffTimestamp() {
    return Timestamp.fromDate(
      DateTime.now().subtract(messageRetention),
    );
  }

  static String _lastMessagePreview(String body, List<String> media) {
    final t = body.trim();
    if (media.isNotEmpty) {
      if (t.isNotEmpty) {
        final snippet = t.length > 70 ? '${t.substring(0, 70)}…' : t;
        return '📷 $snippet';
      }
      return '📷 Photo';
    }
    if (t.isEmpty) return '';
    return t.length > 100 ? '${t.substring(0, 100)}…' : t;
  }

  /// Ensures a conversation doc exists for two users; returns the doc ID.
  /// Uses set-with-merge so we never need a read before the doc exists.
  static Future<String> ensureConversation(String uidA, String uidB) async {
    final docId = Conversation.docId(uidA, uidB);
    await _conversations.doc(docId).set({
      'participants': [uidA, uidB]..sort(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return docId;
  }

  /// Creates or reuses a conversation for [participantUids] (unique, includes caller).
  /// Two-person chats use the deterministic pair id; larger groups use a new doc id.
  static Future<String> ensureGroupConversation(
    List<String> participantUids,
  ) async {
    final sorted = participantUids.toSet().toList()..sort();
    if (sorted.length < 2) {
      throw ArgumentError('At least two participants are required.');
    }
    if (sorted.length == 2) {
      return ensureConversation(sorted[0], sorted[1]);
    }
    final docRef = _conversations.doc();
    await docRef.set({
      'participants': sorted,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Loads participant uid list for an existing conversation (throws if missing).
  static Future<List<String>> fetchParticipantIds(String conversationId) async {
    final snap = await _conversations.doc(conversationId).get();
    if (!snap.exists) {
      throw StateError('Conversation not found.');
    }
    return List<String>.from(snap.data()?['participants'] ?? []);
  }

  /// Send a message in a conversation.
  static Future<void> sendMessage({
    required String conversationId,
    required String fromUid,
    required String body,
    bool isShout = false,
    List<String> mediaUrls = const [],
  }) async {
    final trimmed = body.trim();
    final media = mediaUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(maxMediaUrlsPerMessage)
        .toList();
    if (trimmed.isEmpty && media.isEmpty) {
      throw ArgumentError('Message must include text and/or media.');
    }

    final msgRef = _conversations.doc(conversationId).collection('messages').doc();
    final now = FieldValue.serverTimestamp();
    await msgRef.set({
      'id': msgRef.id,
      'conversationId': conversationId,
      'fromUid': fromUid,
      'body': trimmed,
      'createdAt': now,
      'isShout': isShout,
      'mediaUrls': media,
    });
    final preview = _lastMessagePreview(trimmed, media);
    await _conversations.doc(conversationId).update({
      'lastMessage': preview,
      'lastMessageFrom': fromUid,
      'lastUpdated': now,
      'lastReadAt.$fromUid': now,
    });
  }

  /// Deletes message docs older than [messageRetention] (best-effort batches).
  static Future<void> pruneExpiredMessages(String conversationId) async {
    final cutoff = _retentionCutoffTimestamp();
    final col = _conversations.doc(conversationId).collection('messages');
    for (var round = 0; round < 10; round++) {
      final snap = await col.where('createdAt', isLessThan: cutoff).limit(25).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// Stream of messages in a conversation, newest last (for chat scroll).
  /// Only includes messages from the last [messageRetention] window.
  static Stream<List<DirectMessage>> watchMessages(String conversationId) {
    final cutoff = _retentionCutoffTimestamp();
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = Map<String, dynamic>.from(d.data());
              m['id'] = d.id;
              m['createdAt'] = _iso(m['createdAt']);
              m['conversationId'] = conversationId;
              return DirectMessage.fromMap(m);
            }).toList());
  }

  /// Mark a conversation as read for the given user.
  static Future<void> markConversationRead(String conversationId, String uid) {
    return _conversations.doc(conversationId).update({
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
    });
  }

  /// All conversations for a user, most recent first.
  ///
  /// Sorted in memory so we only need a single-field query (no composite index
  /// for `participants` + `lastUpdated`). Fine for typical inbox sizes.
  static Stream<List<Conversation>> watchConversations(String uid) {
    return _conversations
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => Conversation.fromMap(d.id, d.data()))
              .toList();
          list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
          return list;
        });
  }
}
