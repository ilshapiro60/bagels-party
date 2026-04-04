import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/connection_invite.dart';

class FirestoreInviteRepository {
  FirestoreInviteRepository._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('connectionInvites');

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<void> sendInvite({
    required String fromUid,
    required String fromDisplayName,
    required String fromEmail,
    required String toEmail,
  }) async {
    final toEmailLower = normalizeEmail(toEmail);
    if (toEmailLower.isEmpty) {
      throw ArgumentError('Email is required');
    }
    if (toEmailLower == normalizeEmail(fromEmail)) {
      throw ArgumentError('You cannot invite yourself.');
    }
    final existing = await _invites
        .where('fromUid', isEqualTo: fromUid)
        .where('toEmailLower', isEqualTo: toEmailLower)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _invites.add({
      'fromUid': fromUid,
      'fromDisplayName': fromDisplayName,
      'toEmailLower': toEmailLower,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<ConnectionInvite>> watchIncoming(String? email) {
    if (email == null || email.isEmpty) {
      return const Stream.empty();
    }
    final lower = normalizeEmail(email);
    return _invites
        .where('toEmailLower', isEqualTo: lower)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ConnectionInvite.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  static Future<void> acceptInvite({
    required String inviteId,
    required String toUid,
    required String fromUid,
  }) async {
    final inviteRef = _invites.doc(inviteId);
    final toProfile = _db.collection('profiles').doc(toUid);
    final batch = _db.batch();
    batch.update(inviteRef, {
      'status': 'accepted',
      'toUid': toUid,
      'respondedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      toProfile,
      {
        'friendUids': FieldValue.arrayUnion([fromUid]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<void> declineInvite(String inviteId) async {
    await _invites.doc(inviteId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }
}
