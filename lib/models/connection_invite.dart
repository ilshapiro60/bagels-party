import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionInviteStatus { pending, accepted, declined }

class ConnectionInvite {
  final String id;
  final String fromUid;
  final String fromDisplayName;
  final String toEmailLower;
  final ConnectionInviteStatus status;
  final DateTime createdAt;
  final String? toUid;

  const ConnectionInvite({
    required this.id,
    required this.fromUid,
    required this.fromDisplayName,
    required this.toEmailLower,
    required this.status,
    required this.createdAt,
    this.toUid,
  });

  factory ConnectionInvite.fromDoc(String id, Map<String, dynamic> m) {
    return ConnectionInvite(
      id: id,
      fromUid: m['fromUid'] as String,
      fromDisplayName: m['fromDisplayName'] as String? ?? 'Someone',
      toEmailLower: m['toEmailLower'] as String,
      status: ConnectionInviteStatus.values.byName(
        m['status'] as String? ?? 'pending',
      ),
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      toUid: m['toUid'] as String?,
    );
  }
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}
