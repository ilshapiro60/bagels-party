import 'package:cloud_firestore/cloud_firestore.dart';

/// Available pet-themed emoji reactions.
class PawReaction {
  const PawReaction._({required this.id, required this.emoji, required this.label});

  final String id;
  final String emoji;
  final String label;

  static const paws = PawReaction._(id: 'paws', emoji: '🐾', label: 'Paws up');
  static const heart = PawReaction._(id: 'heart', emoji: '🐶❤️', label: 'Love');
  static const laugh = PawReaction._(id: 'laugh', emoji: '😹', label: 'Haha');
  static const wow = PawReaction._(id: 'wow', emoji: '🙀', label: 'Wow');
  static const sad = PawReaction._(id: 'sad', emoji: '🐕‍🦺', label: 'Sad');
  static const bone = PawReaction._(id: 'bone', emoji: '🦴', label: 'Treat');

  static const all = [paws, heart, laugh, wow, sad, bone];

  static PawReaction? fromId(String? id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// A single user reaction on a post or media item.
class ItemReaction {
  final String id;
  final String targetId;
  final String userId;
  final String reactionId;
  final DateTime createdAt;

  const ItemReaction({
    required this.id,
    required this.targetId,
    required this.userId,
    required this.reactionId,
    required this.createdAt,
  });

  PawReaction? get reaction => PawReaction.fromId(reactionId);

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory ItemReaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return ItemReaction(
      id: doc.id,
      targetId: m['targetId'] as String? ?? '',
      userId: m['userId'] as String? ?? '',
      reactionId: m['reactionId'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
    );
  }
}

/// Aggregated reaction counts for display.
class ReactionSummary {
  final Map<String, int> counts;
  final String? myReactionId;
  final int total;

  const ReactionSummary({
    required this.counts,
    this.myReactionId,
    required this.total,
  });

  static ReactionSummary fromList(List<ItemReaction> reactions, String myUid) {
    final counts = <String, int>{};
    String? mine;
    for (final r in reactions) {
      counts[r.reactionId] = (counts[r.reactionId] ?? 0) + 1;
      if (r.userId == myUid) mine = r.reactionId;
    }
    return ReactionSummary(counts: counts, myReactionId: mine, total: reactions.length);
  }
}
