/// A single message between two users in a conversation.
class DirectMessage {
  final String id;
  final String conversationId;
  final String fromUid;
  final String body;
  final DateTime createdAt;

  /// True if this is a broadcast "shout" rather than a 1:1 message.
  final bool isShout;

  /// Image (or other) URLs uploaded with the message; max enforced when sending.
  final List<String> mediaUrls;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.fromUid,
    required this.body,
    required this.createdAt,
    this.isShout = false,
    this.mediaUrls = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'fromUid': fromUid,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isShout': isShout,
        'mediaUrls': mediaUrls,
      };

  factory DirectMessage.fromMap(Map<String, dynamic> m) => DirectMessage(
        id: m['id'] as String,
        conversationId: m['conversationId'] as String,
        fromUid: m['fromUid'] as String,
        body: m['body'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        isShout: m['isShout'] as bool? ?? false,
        mediaUrls: List<String>.from(m['mediaUrls'] ?? const []),
      );
}

/// Lightweight header for the conversations list.
class Conversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageFrom;
  final DateTime lastUpdated;

  /// Per-user timestamp of when they last read the conversation.
  /// Key = uid, value = DateTime.
  final Map<String, DateTime> lastReadAt;

  const Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageFrom,
    required this.lastUpdated,
    this.lastReadAt = const {},
  });

  String otherUid(String myUid) =>
      participants.firstWhere((u) => u != myUid, orElse: () => myUid);

  /// True when more than two people are in the thread (group chat).
  bool get isGroupChat => participants.length > 2;

  /// Other members besides [myUid] (any order).
  List<String> otherParticipantUids(String myUid) =>
      participants.where((u) => u != myUid).toList();

  /// Whether the given user has unread messages.
  bool hasUnread(String myUid) {
    if (lastMessage == null) return false;
    if (lastMessageFrom == myUid) return false;
    final myRead = lastReadAt[myUid];
    if (myRead == null) return true;
    return lastUpdated.isAfter(myRead);
  }

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'lastMessage': lastMessage,
        'lastMessageFrom': lastMessageFrom,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  static DateTime _parseTs(dynamic v) {
    if (v is String) return DateTime.parse(v);
    if (v != null) {
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory Conversation.fromMap(String docId, Map<String, dynamic> m) {
    final rawRead = m['lastReadAt'];
    final readMap = <String, DateTime>{};
    if (rawRead is Map) {
      for (final entry in rawRead.entries) {
        readMap[entry.key as String] = _parseTs(entry.value);
      }
    }
    return Conversation(
      id: docId,
      participants: List<String>.from(m['participants'] ?? []),
      lastMessage: m['lastMessage'] as String?,
      lastMessageFrom: m['lastMessageFrom'] as String?,
      lastUpdated: _parseTs(m['lastUpdated']),
      lastReadAt: readMap,
    );
  }

  /// Deterministic conversation doc ID from two UIDs.
  static String docId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
