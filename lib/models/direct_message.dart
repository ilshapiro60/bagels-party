/// A single message between two users in a conversation.
class DirectMessage {
  final String id;
  final String conversationId;
  final String fromUid;
  final String body;
  final DateTime createdAt;

  /// True if this is a broadcast "shout" rather than a 1:1 message.
  final bool isShout;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.fromUid,
    required this.body,
    required this.createdAt,
    this.isShout = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'fromUid': fromUid,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isShout': isShout,
      };

  factory DirectMessage.fromMap(Map<String, dynamic> m) => DirectMessage(
        id: m['id'] as String,
        conversationId: m['conversationId'] as String,
        fromUid: m['fromUid'] as String,
        body: m['body'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        isShout: m['isShout'] as bool? ?? false,
      );
}

/// Lightweight header for the conversations list.
class Conversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime lastUpdated;

  const Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.lastUpdated,
  });

  String otherUid(String myUid) =>
      participants.firstWhere((u) => u != myUid, orElse: () => myUid);

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'lastMessage': lastMessage,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory Conversation.fromMap(String docId, Map<String, dynamic> m) {
    final ts = m['lastUpdated'];
    DateTime dt;
    if (ts is String) {
      dt = DateTime.parse(ts);
    } else {
      dt = (ts as dynamic).toDate() as DateTime;
    }
    return Conversation(
      id: docId,
      participants: List<String>.from(m['participants'] ?? []),
      lastMessage: m['lastMessage'] as String?,
      lastUpdated: dt,
    );
  }

  /// Deterministic conversation doc ID from two UIDs.
  static String docId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
