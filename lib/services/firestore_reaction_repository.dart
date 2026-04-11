import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reaction.dart';

class FirestoreReactionRepository {
  FirestoreReactionRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reactions');

  /// Deterministic doc ID so each user can only have one reaction per target.
  static String _docId(String targetId, String userId) => '${targetId}_$userId';

  /// Toggle a reaction: if the user already reacted with this emoji, remove it;
  /// if they reacted with a different emoji, switch; otherwise add.
  static Future<void> toggleReaction({
    required String targetId,
    required String userId,
    required String reactionId,
  }) async {
    final docId = _docId(targetId, userId);
    final ref = _col.doc(docId);
    final snap = await ref.get();

    if (snap.exists && snap.data()?['reactionId'] == reactionId) {
      await ref.delete();
    } else {
      await ref.set({
        'targetId': targetId,
        'userId': userId,
        'reactionId': reactionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream all reactions for a given target (post or media URL hash).
  static Stream<List<ItemReaction>> watchReactions(String targetId) {
    return _col
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map((s) => s.docs.map(ItemReaction.fromDoc).toList());
  }
}
