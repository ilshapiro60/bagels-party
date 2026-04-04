import 'package:cloud_firestore/cloud_firestore.dart';

enum PetBuddyRequestStatus { pending, accepted, declined, cancelled }

class PetBuddyRequest {
  const PetBuddyRequest({
    required this.id,
    required this.fromPetId,
    required this.fromOwnerId,
    required this.toPetId,
    required this.toOwnerId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String fromPetId;
  final String fromOwnerId;
  final String toPetId;
  final String toOwnerId;
  final PetBuddyRequestStatus status;
  final DateTime createdAt;

  static PetBuddyRequestStatus _parseStatus(String? raw) {
    if (raw == null) return PetBuddyRequestStatus.pending;
    for (final v in PetBuddyRequestStatus.values) {
      if (v.name == raw) return v;
    }
    return PetBuddyRequestStatus.pending;
  }

  factory PetBuddyRequest.fromFirestore(
    String id,
    Map<String, dynamic> m,
  ) {
    final created = m['createdAt'];
    final createdAt = created is Timestamp
        ? created.toDate()
        : (created is DateTime
            ? created
            : DateTime.fromMillisecondsSinceEpoch(0));
    return PetBuddyRequest(
      id: id,
      fromPetId: m['fromPetId'] as String? ?? '',
      fromOwnerId: m['fromOwnerId'] as String? ?? '',
      toPetId: m['toPetId'] as String? ?? '',
      toOwnerId: m['toOwnerId'] as String? ?? '',
      status: _parseStatus(m['status'] as String?),
      createdAt: createdAt,
    );
  }
}
