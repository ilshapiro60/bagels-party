/// While this doc exists, neither owner can send new pet buddy requests to the other.
class PetBuddyOwnerMute {
  const PetBuddyOwnerMute({
    required this.docId,
    required this.ownerA,
    required this.ownerB,
    required this.mutedBy,
  });

  final String docId;
  final String ownerA;
  final String ownerB;
  final String mutedBy;

  String otherUid(String myUid) => myUid == ownerA ? ownerB : ownerA;

  factory PetBuddyOwnerMute.fromFirestore(String id, Map<String, dynamic> m) {
    final p = List<String>.from(m['participants'] as List? ?? []);
    return PetBuddyOwnerMute(
      docId: id,
      ownerA: p.isNotEmpty ? p[0] : '',
      ownerB: p.length > 1 ? p[1] : '',
      mutedBy: m['mutedBy'] as String? ?? '',
    );
  }
}
