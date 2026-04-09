import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../models/passport_entry.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_passport_repository.dart';
import '../../services/firestore_pet_repository.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/paw_file_image.dart';

class AddPassportEntryScreen extends ConsumerStatefulWidget {
  const AddPassportEntryScreen({
    super.key,
    this.initialPetId,
    this.existingEntry,
  });

  final String? initialPetId;

  /// When non-null, the screen edits this entry instead of creating a new one.
  final PassportEntry? existingEntry;

  bool get isEditing => existingEntry != null;

  @override
  ConsumerState<AddPassportEntryScreen> createState() =>
      _AddPassportEntryScreenState();
}

class _AddPassportEntryScreenState extends ConsumerState<AddPassportEntryScreen> {
  final _titleController = TextEditingController();
  final _hostController = TextEditingController();
  final _themeController = TextEditingController();
  final _metPetsController = TextEditingController();
  final _notesController = TextEditingController();
  final _warmUpController = TextEditingController(text: '0');

  Pet? _selectedPet;
  Meetup? _linkedMeetup;
  bool _useLinkedMeetup = true;
  PlayOutcome _outcome = PlayOutcome.good;
  double? _rating;
  bool _wasAnxious = false;
  bool _playedWell = true;
  bool _isPublic = false;
  final List<String> _localPhotoPaths = [];
  final List<String> _existingPhotoUrls = [];
  bool _saving = false;
  DateTime _partyDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    final existing = widget.existingEntry;
    if (existing != null) {
      _titleController.text = existing.meetupTitle;
      _hostController.text = existing.hostName;
      _themeController.text = existing.meetupTheme ?? '';
      _metPetsController.text = existing.metPetNames.join(', ');
      _notesController.text = existing.behaviorNotes ?? '';
      _warmUpController.text = existing.warmUpMinutes.toString();
      _outcome = existing.playOutcome;
      _rating = existing.rating;
      _wasAnxious = existing.wasAnxious;
      _playedWell = existing.playedWell;
      _isPublic = existing.isPublic;
      _partyDate = existing.date;
      _existingPhotoUrls.addAll(existing.photoUrls);
      _useLinkedMeetup = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pets = ref.read(userPetsProvider);
      if (pets.isEmpty) return;
      Pet? initial;
      final targetPetId = existing?.petId ?? widget.initialPetId;
      if (targetPetId != null) {
        for (final p in pets) {
          if (p.id == targetPetId) {
            initial = p;
            break;
          }
        }
      }
      setState(() {
        _selectedPet = initial ?? pets.first;
      });
    });
  }

  bool _defaultedMeetup = false;

  @override
  void dispose() {
    _titleController.dispose();
    _hostController.dispose();
    _themeController.dispose();
    _metPetsController.dispose();
    _notesController.dispose();
    _warmUpController.dispose();
    super.dispose();
  }

  List<String> _parseMetNames() {
    return _metPetsController.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    try {
      final path = source == ImageSource.gallery
          ? await pickPhotoFromGallery()
          : await pickPhotoFromCamera();
      if (path != null) setState(() => _localPhotoPaths.add(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add photo: $e')),
        );
      }
    }
  }

  Future<void> _pickPartyDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _partyDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _partyDate = d);
  }

  Future<void> _save() async {
    final pets = ref.read(userPetsProvider);
    final pet = _selectedPet ?? (pets.isNotEmpty ? pets.first : null);
    final user = ref.read(authStateProvider).user;
    if (pet == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a pet and sign in to save.')),
      );
      return;
    }
    if (!isFirebaseInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase is not configured.')),
      );
      return;
    }

    String meetupId;
    String meetupTitle;
    String hostName;
    String? meetupTheme;

    if (_useLinkedMeetup && _linkedMeetup != null) {
      final m = _linkedMeetup!;
      meetupId = m.id;
      meetupTitle = m.title;
      hostName = m.hostName;
      meetupTheme = m.theme;
    } else {
      meetupTitle = _titleController.text.trim();
      hostName = _hostController.text.trim();
      meetupTheme = _themeController.text.trim().isEmpty
          ? null
          : _themeController.text.trim();
      if (meetupTitle.isEmpty || hostName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a party title and host name (or link a party).'),
          ),
        );
        return;
      }
      meetupId = const Uuid().v4();
    }

    final metNames = _parseMetNames();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final warmUp = int.tryParse(_warmUpController.text.trim()) ?? 0;

    final entryId = widget.existingEntry?.id ?? const Uuid().v4();
    final isCreate = widget.existingEntry == null;
    final storage = FirebaseStorageService.instance;
    final photoUrls = <String>[..._existingPhotoUrls];

    setState(() => _saving = true);
    try {
      for (final path in _localPhotoPaths) {
        final url = await storage.uploadPassportMedia(
          localPath: path,
          entryId: entryId,
          allowLocalFallback: false,
        );
        if (!FirestorePetRepository.isShareableMediaUrl(url)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo upload failed. Check connection and try again.'),
              ),
            );
          }
          return;
        }
        photoUrls.add(url);
      }

      final searchText = PassportEntry.buildSearchText(
        meetupTitle: meetupTitle,
        meetupTheme: meetupTheme,
        behaviorNotes: notes,
        hostName: hostName,
        metPetNames: metNames,
        petName: pet.name,
      );

      final entry = PassportEntry(
        id: entryId,
        ownerId: user.id,
        petId: pet.id,
        petName: pet.name,
        meetupId: meetupId,
        meetupTitle: meetupTitle,
        meetupTheme: meetupTheme,
        date: _partyDate,
        hostName: hostName,
        metPetNames: metNames,
        rating: _rating,
        behaviorNotes: notes,
        playOutcome: _outcome,
        photoUrls: photoUrls,
        videoPaths: const [],
        wasAnxious: _wasAnxious,
        playedWell: _playedWell,
        warmUpMinutes: warmUp.clamp(0, 999),
        isPublic: _isPublic,
        searchText: searchText,
      );

      await FirestorePassportRepository.upsertEntry(entry, isCreate: isCreate);
      ref.invalidate(passportMyEntriesProvider);
      ref.invalidate(passportPublicEntriesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Entry updated' : 'Passport entry saved'),
          backgroundColor: PawPartyColors.success,
        ),
      );
      context.pop();
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(userPetsProvider);
    final meetups = ref.watch(upcomingMeetupsProvider).value ?? [];

    if (pets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add journal entry')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Add a pet first to create passport entries.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/create-pet'),
                  child: const Text('Add pet'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_defaultedMeetup && meetups.isNotEmpty && _linkedMeetup == null) {
      _defaultedMeetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _linkedMeetup = meetups.first);
      });
    }

    final pet = _selectedPet ?? pets.first;

    return Scaffold(
        appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit journal entry' : 'Add journal entry'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Pet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<Pet>(
            initialValue: pet,
            items: pets
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name),
                  ),
                )
                .toList(),
            onChanged: (p) => setState(() => _selectedPet = p),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pets),
            ),
          ),
          const SizedBox(height: 20),
          Text('Party', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Link to one of my hosted parties'),
            value: _useLinkedMeetup && meetups.isNotEmpty,
            onChanged: meetups.isEmpty
                ? null
                : (v) => setState(() {
                      _useLinkedMeetup = v;
                      if (v && _linkedMeetup == null && meetups.isNotEmpty) {
                        _linkedMeetup = meetups.first;
                      }
                    }),
          ),
          if (_useLinkedMeetup && meetups.isNotEmpty) ...[
            DropdownButtonFormField<Meetup>(
              initialValue: _linkedMeetup,
              items: meetups
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (m) => setState(() => _linkedMeetup = m),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Party',
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Party title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _themeController,
              decoration: const InputDecoration(
                labelText: 'Theme (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Party date'),
            subtitle: Text(
              MaterialLocalizations.of(context).formatFullDate(_partyDate),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickPartyDate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _metPetsController,
            decoration: const InputDecoration(
              labelText: 'Pets they met (comma-separated)',
              border: OutlineInputBorder(),
              hintText: 'e.g. Max, Luna',
            ),
          ),
          const SizedBox(height: 16),
          Text('How did it go?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PlayOutcome.values.map((o) {
              final sel = _outcome == o;
              return ChoiceChip(
                label: Text('${o.emoji} ${o.label}'),
                selected: sel,
                onSelected: (_) => setState(() => _outcome = o),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Rating (optional)', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _rating ?? 3,
                  min: 1,
                  max: 5,
                  divisions: 8,
                  label: _rating?.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _rating = null),
                child: const Text('Clear'),
              ),
            ],
          ),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _warmUpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Warm-up minutes',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            title: const Text('Seemed anxious'),
            value: _wasAnxious,
            onChanged: (v) => setState(() => _wasAnxious = v),
          ),
          SwitchListTile(
            title: const Text('Played well overall'),
            value: _playedWell,
            onChanged: (v) => setState(() => _playedWell = v),
          ),
          SwitchListTile(
            title: const Text('Share on Community (public)'),
            subtitle: const Text(
              'Other members can see this entry and search it.',
            ),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 12),
          Text('Photos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._existingPhotoUrls.map(
                (url) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: PawFileOrNetworkImage(path: url),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _existingPhotoUrls.remove(url)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ..._localPhotoPaths.map(
                (path) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: PawFileOrNetworkImage(path: path),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _localPhotoPaths.remove(path)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add photo'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(widget.isEditing ? 'Update entry' : 'Save entry'),
          ),
        ],
      ),
    );
  }
}
