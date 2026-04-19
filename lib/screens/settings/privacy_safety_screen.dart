import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';

import '../../config/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_profile_repository.dart';

class PrivacySafetyScreen extends ConsumerWidget {
  const PrivacySafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy & Safety'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Privacy Policy'),
              Tab(text: 'Block List'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PrivacyPolicyTab(),
            _BlockListTab(),
          ],
        ),
      ),
    );
  }
}

// ── Privacy Policy ────────────────────────────────────────────────────────

class _PrivacyPolicyTab extends StatelessWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _PolicySection(
          title: 'Information We Collect',
          body:
              'We collect information you provide directly, such as your name, email address, '
              'pet details, photos, and location. We also collect usage data such as pages '
              'viewed, features used, and interaction logs to improve the app experience.',
        ),
        _PolicySection(
          title: 'How We Use Your Information',
          body:
              'Your information is used to provide and improve ZumiTok services, match you '
              'with nearby pet parents, send notifications about parties and messages, and '
              'ensure platform safety. We do not sell your personal data to third parties.',
        ),
        _PolicySection(
          title: 'Location Data',
          body:
              'Location is used to show nearby pets, parties, and vet clinics. Your precise '
              'location is never shared with other users — only a general area label (e.g. '
              '"Riverside") is displayed on your profile.',
        ),
        _PolicySection(
          title: 'Photos & Media',
          body:
              'Photos and videos you upload are stored securely and are visible to other '
              'ZumiTok users in your area. You may delete your media at any time from your '
              'profile or pet pages.',
        ),
        _PolicySection(
          title: 'Data Retention',
          body:
              'Your data is retained while your account is active. When you delete your '
              'account, your profile, pets, and associated media are permanently removed '
              'within 30 days.',
        ),
        _PolicySection(
          title: 'Children\'s Privacy',
          body:
              'ZumiTok is not directed to children under 13. We do not knowingly collect '
              'personal information from children under 13. If you believe a child has '
              'provided us data, please contact support.',
        ),
        _PolicySection(
          title: 'Contact',
          body:
              'For privacy-related questions or data requests, contact us at '
              '${AppConstants.supportEmail}.',
        ),
      ],
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: PawPartyColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Block List ────────────────────────────────────────────────────────────

class _BlockListTab extends ConsumerStatefulWidget {
  const _BlockListTab();

  @override
  ConsumerState<_BlockListTab> createState() => _BlockListTabState();
}

class _BlockListTabState extends ConsumerState<_BlockListTab> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    if (user == null) return const SizedBox.shrink();

    final blockedUids = user.blockedUids;

    if (blockedUids.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 52, color: PawPartyColors.success),
            const SizedBox(height: 12),
            Text('No blocked users',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PawPartyColors.textPrimary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: blockedUids.length,
      itemBuilder: (context, i) =>
          _BlockedUserTile(uid: blockedUids[i], myUid: user.id),
    );
  }
}

class _BlockedUserTile extends ConsumerStatefulWidget {
  const _BlockedUserTile({required this.uid, required this.myUid});
  final String uid;
  final String myUid;

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  String? _name;
  bool _unblocking = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final profile =
        await FirestoreProfileRepository.fetchProfile(widget.uid);
    if (mounted) setState(() => _name = profile?.displayName ?? 'Unknown user');
  }

  Future<void> _unblock() async {
    setState(() => _unblocking = true);
    try {
      await FirestoreProfileRepository.unblockUser(
          myUid: widget.myUid, targetUid: widget.uid);
      final user = ref.read(authStateProvider).user!;
      final updated = List<String>.from(user.blockedUids)..remove(widget.uid);
      ref
          .read(authStateProvider.notifier)
          .updateUser(user.copyWithBlockedUids(updated));
    } finally {
      if (mounted) setState(() => _unblocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: PawPartyColors.primary.withValues(alpha: 0.12),
        child:
            Icon(Icons.person_outline, color: PawPartyColors.primary, size: 22),
      ),
      title: Text(_name ?? '…',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: TextButton(
        onPressed: _unblocking ? null : _unblock,
        style: TextButton.styleFrom(foregroundColor: PawPartyColors.primary),
        child: _unblocking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Unblock'),
      ),
    );
  }
}
