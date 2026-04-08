enum PartyInviteStatus { pending, accepted, declined }

PartyInviteStatus _parseStatus(Object? raw) {
  if (raw is! String) return PartyInviteStatus.pending;
  for (final v in PartyInviteStatus.values) {
    if (v.name == raw) return v;
  }
  return PartyInviteStatus.pending;
}

class PartyInvite {
  final String id;
  final String meetupId;
  final String meetupTitle;
  final String hostId;
  final String hostName;
  final String guestId;
  final String guestName;
  final PartyInviteStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;

  const PartyInvite({
    required this.id,
    required this.meetupId,
    required this.meetupTitle,
    required this.hostId,
    required this.hostName,
    required this.guestId,
    required this.guestName,
    this.status = PartyInviteStatus.pending,
    required this.sentAt,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'meetupId': meetupId,
        'meetupTitle': meetupTitle,
        'hostId': hostId,
        'hostName': hostName,
        'guestId': guestId,
        'guestName': guestName,
        'status': status.name,
        'sentAt': sentAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
      };

  factory PartyInvite.fromFirestore(String docId, Map<String, dynamic> m) {
    return PartyInvite(
      id: docId,
      meetupId: m['meetupId'] as String? ?? '',
      meetupTitle: m['meetupTitle'] as String? ?? '',
      hostId: m['hostId'] as String? ?? '',
      hostName: m['hostName'] as String? ?? '',
      guestId: m['guestId'] as String? ?? '',
      guestName: m['guestName'] as String? ?? '',
      status: _parseStatus(m['status']),
      sentAt: _parseDate(m['sentAt']),
      respondedAt: m['respondedAt'] != null ? _parseDate(m['respondedAt']) : null,
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is Map && v.containsKey('_seconds')) {
    return DateTime.fromMillisecondsSinceEpoch(
      (v['_seconds'] as int) * 1000,
    );
  }
  return DateTime.now();
}
