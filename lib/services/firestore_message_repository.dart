import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/direct_message.dart';

class FirestoreMessageRepository {
  FirestoreMessageRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  static String _iso(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String) return v;
    return DateTime.now().toIso8601String();
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

  /// Send a message in a conversation.
  static Future<void> sendMessage({
    required String conversationId,
    required String fromUid,
    required String body,
    bool isShout = false,
  }) async {
    final msgRef = _conversations.doc(conversationId).collection('messages').doc();
    final now = FieldValue.serverTimestamp();
    await msgRef.set({
      'id': msgRef.id,
      'conversationId': conversationId,
      'fromUid': fromUid,
      'body': body,
      'createdAt': now,
      'isShout': isShout,
    });
    await _conversations.doc(conversationId).update({
      'lastMessage': body.length > 100 ? '${body.substring(0, 100)}…' : body,
      'lastUpdated': now,
    });
  }

  /// Stream of messages in a conversation, newest last (for chat scroll).
  static Stream<List<DirectMessage>> watchMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
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

  /// All conversations for a user, most recent first.
  static Stream<List<Conversation>> watchConversations(String uid) {
    return _conversations
        .where('participants', arrayContains: uid)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Conversation.fromMap(d.id, d.data()))
            .toList());
  }
}
