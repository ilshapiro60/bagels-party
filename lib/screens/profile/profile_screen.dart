import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../widgets/owner_media_strip.dart';
import '../../widgets/paw_file_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final pets = ref.watch(userPetsProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Profile settings',
            onPressed: () => _openProfileSettings(context, ref, user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(context, ref, user),
            const SizedBox(height: 20),
            const OwnerMediaStrip(),
            const SizedBox(height: 20),
            _buildStatsRow(context, user),
            const SizedBox(height: 24),
            _buildHostPassCard(context, user),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'My Pets',
              pets.map((pet) => _buildPetListItem(context, pet)).toList(),
            ),
            const SizedBox(height: 24),
            _buildMenuItems(context, ref),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: PawPartyColors.primary.withValues(alpha: 0.15),
          child: user.photoUrl != null && user.photoUrl!.isNotEmpty
              ? ClipOval(
                  child: PawFileOrNetworkImage(
                    path: user.photoUrl!,
                    width: 100,
                    height: 100,
                  ),
                )
              : Text(
                  user.displayName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: PawPartyColors.primary,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          user.displayName,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 16, color: PawPartyColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              user.neighborhood ?? 'Set your neighborhood',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBioEditor(context, ref, user),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  if (user.bio != null && user.bio!.isNotEmpty)
                    Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: PawPartyColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text(
                      'Add a short bio for neighbors',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: PawPartyColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: PawPartyColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildStatsRow(BuildContext context, user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(context, '${user.hostCount}', 'Hosted', Icons.home),
          Container(width: 1, height: 40, color: PawPartyColors.divider),
          _stat(context, '${user.attendCount}', 'Attended', Icons.celebration),
          Container(width: 1, height: 40, color: PawPartyColors.divider),
          _stat(context, user.hostRating.toStringAsFixed(1), 'Host Rating', Icons.star),
          Container(width: 1, height: 40, color: PawPartyColors.divider),
          _stat(context, user.guestRating.toStringAsFixed(1), 'Guest Rating', Icons.thumb_up),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: PawPartyColors.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PawPartyColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: PawPartyColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHostPassCard(BuildContext context, user) {
    if (user.isHostPassActive) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [PawPartyColors.pizzaGold, PawPartyColors.primary],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, size: 40, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Host Pass Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlimited hosting, full analytics',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final freeLeft = AppConstants.maxFreeHostings - user.hostCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PawPartyColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.local_pizza, size: 32, color: PawPartyColors.pizzaGold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      freeLeft > 0
                          ? '$freeLeft free parties left'
                          : 'Upgrade to Host Pass',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${AppConstants.hostPassPrice}/mo for unlimited hosting',
                      style: TextStyle(
                        fontSize: 13,
                        color: PawPartyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (freeLeft <= 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: PawPartyColors.pizzaGold,
                ),
                child: const Text('Get Host Pass'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildPetListItem(BuildContext context, pet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: PawPartyColors.primary.withValues(alpha: 0.1),
            child: pet.photoUrl != null && pet.photoUrl!.isNotEmpty
                ? ClipOval(
                    child: PawFileOrNetworkImage(
                      path: pet.photoUrl!,
                      width: 48,
                      height: 48,
                    ),
                  )
                : Text(
                    pet.name[0],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: PawPartyColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${pet.breed ?? pet.type} • ${pet.ageDisplay}',
                  style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PawPartyColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pet.energyLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PawPartyColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _menuItem(Icons.child_care, 'Children in Household', 'Ages: 6, 9', () {}),
        _menuItem(Icons.notifications_outlined, 'Notifications', null, () {}),
        _menuItem(Icons.privacy_tip_outlined, 'Privacy & Safety', null, () {}),
        _menuItem(Icons.help_outline, 'Help & Support', null, () {}),
        _menuItem(Icons.info_outline, 'About ${AppConstants.appName}', null, () {}),
        const SizedBox(height: 8),
        _menuItem(
          Icons.logout,
          'Sign Out',
          null,
          () {
            ref.read(authStateProvider.notifier).signOut().then((_) {
              if (context.mounted) context.go('/login');
            });
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    String? subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? PawPartyColors.error : PawPartyColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? PawPartyColors.error : PawPartyColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary))
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: PawPartyColors.textHint,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

void _openProfileSettings(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('Edit bio'),
            subtitle: const Text('Short line under your name'),
            onTap: () {
              Navigator.pop(ctx);
              _showBioEditor(context, ref, user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Edit display name'),
            onTap: () {
              Navigator.pop(ctx);
              _showDisplayNameEditor(context, ref, user);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _showBioEditor(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  final controller = TextEditingController(text: user.bio ?? '');
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your bio'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        maxLength: 280,
        decoration: const InputDecoration(
          hintText: 'Dog dad, pizza enthusiast…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (!context.mounted || submitted == null) return;
  final trimmed = submitted.trim();
  ref.read(authStateProvider.notifier).updateUser(
        user.copyWithProfile(
          updateBio: true,
          bio: trimmed.isEmpty ? null : trimmed,
        ),
      );
}

Future<void> _showDisplayNameEditor(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  final controller = TextEditingController(text: user.displayName);
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Display name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (!context.mounted || submitted == null) return;
  final trimmed = submitted.trim();
  if (trimmed.isEmpty) return;
  await ref.read(authStateProvider.notifier).updateDisplayName(trimmed);
}
