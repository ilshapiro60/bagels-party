import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/owner_media_strip.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_party_pizza_icon.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final pets = ref.watch(userPetsProvider);

    if (user == null) return const SizedBox.shrink();

    final canPop = context.canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.mounted) context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: canPop
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => context.go('/home'),
                ),
          automaticallyImplyLeading: canPop,
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
            _buildHostingPricingCard(context, user),
            const SizedBox(height: 24),
            _buildMyPetsSection(context, ref, pets),
            const SizedBox(height: 24),
            _buildMenuItems(context, ref, user),
            const SizedBox(height: 32),
          ],
        ),
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
        GestureDetector(
          onTap: () => _pickProfilePhoto(context, ref, user),
          child: Stack(
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PawPartyColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
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
                    'Edit Bio',
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

  Widget _buildHostingPricingCard(BuildContext context, user) {
    if (user.isBusinessAccount) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PawPartyColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PawPartyColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, size: 28, color: PawPartyColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Business event pricing',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _pricingRow('\$${AppConstants.partyFeeBizSmall.toStringAsFixed(2)}',
                'Up to ${AppConstants.bizSmallGuestMax} guests'),
            const SizedBox(height: 6),
            _pricingRow('\$${AppConstants.partyFeeBizMedium.toStringAsFixed(2)}',
                '${AppConstants.bizSmallGuestMax + 1}–${AppConstants.bizMediumGuestMax} guests'),
            const SizedBox(height: 6),
            _pricingRow('\$${AppConstants.partyFeeBizLarge.toStringAsFixed(2)}',
                '${AppConstants.bizMediumGuestMax + 1}+ guests'),
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
      child: Row(
        children: [
          const PawPartyPizzaIcon(size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  freeLeft > 0
                      ? '$freeLeft free ${freeLeft == 1 ? 'party' : 'parties'} remaining'
                      : '\$${AppConstants.partyFeeRegular.toStringAsFixed(2)} per party',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  freeLeft > 0
                      ? 'Then \$${AppConstants.partyFeeRegular.toStringAsFixed(2)} per party'
                      : 'First ${AppConstants.maxFreeHostings} were free',
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
    );
  }

  Widget _pricingRow(String price, String description) {
    return Row(
      children: [
        const SizedBox(width: 40),
        SizedBox(
          width: 56,
          child: Text(
            price,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: PawPartyColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: PawPartyColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyPetsSection(
    BuildContext context,
    WidgetRef ref,
    List<Pet> pets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('My Pets', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/create-pet'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add pet'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PawPartyColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
            ),
            child: Text(
              'No pets yet. Add a pet to set up their profile, photos, and videos. '
              'New photos and videos you upload are also shared on the Area newsletter when your neighborhood is set.',
              style: TextStyle(fontSize: 14, color: PawPartyColors.textSecondary, height: 1.35),
            ),
          )
        else
          ...pets.map((pet) => _buildPetListItem(context, ref, pet)),
      ],
    );
  }

  Future<void> _confirmDeletePet(
    BuildContext context,
    WidgetRef ref,
    Pet pet,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${pet.name}?'),
        content: const Text(
          'This deletes the pet profile and gallery from your account. '
          'Meetups or invites that reference this pet may need to be updated separately.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PawPartyColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(userPetsProvider.notifier).removePet(pet.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pet.name} was removed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete pet: $e')),
        );
      }
    }
  }

  Widget _buildPetListItem(BuildContext context, WidgetRef ref, Pet pet) {
    final thumb = pet.photoUrl?.trim();
    final hasPhoto = thumb != null && thumb.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PawPartyColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: PawPartyColors.divider.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push('/edit-pet/${pet.id}', extra: pet),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: PawPartyColors.primary.withValues(alpha: 0.1),
                          child: hasPhoto
                              ? ClipOval(
                                  child: PawFileOrNetworkImage(
                                    path: thumb,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: PawPartyColors.primary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
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
                              const SizedBox(height: 4),
                              Text(
                                'Tap to edit profile & media',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PawPartyColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: PawPartyColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pet.energyLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PawPartyColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'view') {
                    context.push('/pet/${pet.id}');
                  } else if (value == 'delete') {
                    _confirmDeletePet(context, ref, pet);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'view', child: Text('View public profile')),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete pet', style: TextStyle(color: PawPartyColors.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItems(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) {
    return Column(
      children: [
        _menuItem(
          Icons.group_add_outlined,
          'Friends & invites',
          'Connect with other pet parents',
          () => context.push('/friends'),
        ),
        _menuItem(
          Icons.local_hospital_outlined,
          'Community vet clinics',
          'Clinics other members linked on pets',
          () => context.push('/community-vet-clinics'),
        ),
        _menuItem(
          Icons.forum_outlined,
          'Area newsletter',
          'Neighborhood posts & comments',
          () => context.push('/neighborhood-news'),
        ),
        if (user.isModerator) ...[
          _menuItem(
            Icons.flag_outlined,
            'Moderation — newsletter',
            'Pending reports queue',
            () => context.push('/moderation/neighborhood-news'),
          ),
          _menuItem(
            Icons.report_outlined,
            'Moderation — messages',
            'Private chat conduct reports',
            () => context.push('/moderation/chat-safety'),
          ),
        ],
        _menuItem(
          Icons.notifications_outlined,
          'Notifications',
          'Push alerts for parties & messages',
          () => _openNotificationSettings(context),
        ),
        _menuItem(
          Icons.privacy_tip_outlined,
          'Privacy & Safety',
          'Account privacy, data & blocked users',
          () => context.push('/settings/privacy'),
        ),
        if (defaultTargetPlatform == TargetPlatform.iOS)
          _menuItem(
            Icons.storefront_outlined,
            'In-App Purchases',
            'Verify hosting products from the App Store',
            () => context.push('/settings/iap-status'),
          ),
        _menuItem(
          Icons.help_outline,
          'Help & Support',
          'FAQs, contact & feedback',
          () => context.push('/settings/help'),
        ),
        _menuItem(
          Icons.info_outline,
          'About ${AppConstants.appName}',
          'Version, terms & privacy policy',
          () => context.push('/settings/about'),
        ),
        const SizedBox(height: 8),
        _menuItem(
          Icons.delete_forever_outlined,
          'Delete account',
          'Permanently remove your data',
          () => _confirmDeleteAccount(context, ref),
          isDestructive: true,
        ),
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

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountConfirmationDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(authStateProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    // Defer navigation: signOut rebuilds this route to an empty subtree first;
    // navigating in the same frame can trip framework assertions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/login');
    });
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

Future<void> _pickProfilePhoto(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;

  final path = choice == 'camera'
      ? await pickPhotoFromCamera()
      : await pickPhotoFromGallery();
  if (path == null || !context.mounted) return;

  final uploaded =
      await FirebaseStorageService.instance.uploadProfileAvatar(path);
  ref.read(authStateProvider.notifier).updateUser(
        user.copyWithProfile(photoUrl: uploaded),
      );
}

void _openNotificationSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Notification Settings',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Push notifications are managed by your device. '
                'Tap below to open system settings.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.app_settings_alt_outlined),
              title: const Text('Open system notification settings'),
              onTap: () {
                Navigator.pop(ctx);
                _launchAppNotificationSettings();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _launchAppNotificationSettings() async {
  // Opens the app's notification settings page in the OS.
  // firebase_messaging's requestPermission handles the initial prompt;
  // this is for users who denied and want to re-enable later.
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {}
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
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.storefront,
              color: user.isBusinessAccount ? PawPartyColors.primary : null,
            ),
            title: const Text('Business account'),
            subtitle: Text(
              user.isBusinessAccount
                  ? user.businessName ?? 'Set up your business profile'
                  : 'Host public events as a local business',
            ),
            trailing: user.isBusinessAccount
                ? const Icon(Icons.check_circle, color: PawPartyColors.primary)
                : null,
            onTap: () {
              Navigator.pop(ctx);
              _showBusinessEditor(context, ref, user);
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
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) => _BioEditorDialog(initialValue: user.bio ?? ''),
  );
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
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) => _DisplayNameEditorDialog(initialValue: user.displayName),
  );
  if (!context.mounted || submitted == null) return;
  final trimmed = submitted.trim();
  if (trimmed.isEmpty) return;
  await ref.read(authStateProvider.notifier).updateDisplayName(trimmed);
}

class _BioEditorDialog extends StatefulWidget {
  const _BioEditorDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_BioEditorDialog> createState() => _BioEditorDialogState();
}

class _BioEditorDialogState extends State<_BioEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your bio'),
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DisplayNameEditorDialog extends StatefulWidget {
  const _DisplayNameEditorDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_DisplayNameEditorDialog> createState() => _DisplayNameEditorDialogState();
}

class _DisplayNameEditorDialogState extends State<_DisplayNameEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Display name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

const _businessCategories = [
  'Veterinary Clinic',
  'Pet Store',
  'Groomer',
  'Dog Park',
  'Training',
  'Boarding / Daycare',
  'Other',
];

Future<void> _showBusinessEditor(
  BuildContext context,
  WidgetRef ref,
  UserProfile user,
) async {
  final nameCtrl = TextEditingController(text: user.businessName ?? '');
  String selectedCategory = user.businessCategory ?? _businessCategories.first;
  bool enabled = user.isBusinessAccount;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Business account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable business profile'),
                  value: enabled,
                  activeTrackColor: PawPartyColors.primary,
                  onChanged: (v) => setDialogState(() => enabled = v),
                ),
                if (enabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                      hintText: 'e.g., Happy Paws Clinic',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _businessCategories.contains(selectedCategory)
                        ? selectedCategory
                        : _businessCategories.first,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _businessCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedCategory = v);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'enabled': enabled,
                'name': nameCtrl.text.trim(),
                'category': selectedCategory,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
  nameCtrl.dispose();
  if (!context.mounted || result == null) return;

  final isEnabled = result['enabled'] as bool;
  final updated = user.copyWithBusiness(
    isBusinessAccount: isEnabled,
    businessName: isEnabled ? result['name'] as String? : null,
    businessCategory: isEnabled ? result['category'] as String? : null,
    clearBusinessFields: !isEnabled,
  );
  ref.read(authStateProvider.notifier).updateUser(updated);
}

/// Owns [TextEditingController] so it is disposed only after the dialog route
/// has unmounted — disposing immediately after [showDialog] returns can assert
/// (`_dependents.isEmpty`) while [TextField] is still tearing down.
class _DeleteAccountConfirmationDialog extends StatefulWidget {
  const _DeleteAccountConfirmationDialog();

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState extends State<_DeleteAccountConfirmationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes your profile, pets, messages, parties, and other '
            '${AppConstants.appName} data tied to this account. This cannot be undone.',
            style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_controller.text.trim() == 'DELETE') {
              Navigator.pop(context, true);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Type DELETE exactly to confirm.')),
              );
            }
          },
          style: TextButton.styleFrom(foregroundColor: PawPartyColors.error),
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}
