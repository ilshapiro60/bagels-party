import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/fullscreen_video.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_video_thumb.dart';
import '../../widgets/personality_slider.dart';
import '../../services/firebase_storage_service.dart';

class CreatePetScreen extends ConsumerStatefulWidget {
  const CreatePetScreen({super.key});

  @override
  ConsumerState<CreatePetScreen> createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends ConsumerState<CreatePetScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final _totalSteps = 4;

  // Step 1: Basics
  final _nameController = TextEditingController();
  String _selectedType = 'Dog';
  String _selectedGender = AppConstants.petGenders[0];
  final _breedController = TextEditingController();
  String _selectedSize = AppConstants.sizeCategories[2];
  int _ageYears = 1;
  int _ageMonths = 0;
  String? _profilePhotoPath;
  final List<String> _galleryPhotos = [];
  final List<String> _galleryVideos = [];

  // Step 2: Personality
  double _energyLevel = 0.5;
  double _socialComfort = 0.5;
  double _kidTolerance = 0.5;
  double _sizeTolerance = 0.5;

  // Step 3: Play & Triggers
  final Set<String> _selectedPlayStyles = {};
  final Set<String> _selectedTriggers = {};

  // Step 4: Bio & Health
  final _bioController = TextEditingController();
  bool _isSpayedNeutered = false;
  bool _isVaccinated = false;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      await _savePet();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _savePet() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again to add a pet.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final petId = const Uuid().v4();
      final storage = FirebaseStorageService.instance;

      String? photoUrl = _profilePhotoPath;
      if (photoUrl != null) {
        photoUrl = await storage.uploadPetAvatar(
          localPath: photoUrl,
          petId: petId,
        );
      }

      final photoGallery = <String>[];
      for (final path in _galleryPhotos) {
        photoGallery.add(
          await storage.uploadPetGalleryPhoto(localPath: path, petId: petId),
        );
      }
      final videoPaths = <String>[];
      for (final path in _galleryVideos) {
        videoPaths.add(
          await storage.uploadPetVideo(localPath: path, petId: petId),
        );
      }

      final pet = Pet(
        id: petId,
        ownerId: user.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        gender: _selectedGender,
        size: _selectedSize,
        ageYears: _ageYears,
        ageMonths: _ageMonths,
        photoUrl: photoUrl,
        photoGallery: photoGallery,
        videoPaths: videoPaths,
        energyLevel: _energyLevel,
        socialComfort: _socialComfort,
        kidTolerance: _kidTolerance,
        sizeTolerance: _sizeTolerance,
        playStyles: _selectedPlayStyles.toList(),
        triggers: _selectedTriggers.toList(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        isSpayedNeutered: _isSpayedNeutered,
        isVaccinated: _isVaccinated,
        createdAt: DateTime.now(),
      );

      await ref.read(userPetsProvider.notifier).addPet(pet);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pet.name} has joined ${AppConstants.appName}! 🎉'),
          backgroundColor: PawPartyColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
    final path = source == ImageSource.gallery
        ? await pickPhotoFromGallery()
        : await pickPhotoFromCamera();
    if (path != null) setState(() => _profilePhotoPath = path);
  }

  Future<void> _addPetGalleryPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Photo with camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    final path = source == ImageSource.gallery
        ? await pickPhotoFromGallery()
        : await pickPhotoFromCamera();
    if (path != null) setState(() => _galleryPhotos.add(path));
  }

  Future<void> _addPetVideo() async {
    final useCamera = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video from gallery'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record video'),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (!mounted || useCamera == null) return;
    final path = useCamera
        ? await pickVideoFromCamera()
        : await pickVideoFromGallery();
    if (path != null) setState(() => _galleryVideos.add(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _previousStep,
        ),
        title: const Text('Add Your Pet'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: TextStyle(
                color: PawPartyColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Basics(),
                _buildStep2Personality(),
                _buildStep3PlayStyle(),
                _buildStep4Bio(),
              ],
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / _totalSteps,
          backgroundColor: PawPartyColors.divider,
          valueColor: const AlwaysStoppedAnimation(PawPartyColors.primary),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildStep1Basics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The Basics', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Tell us about your furry (or feathery) friend',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: PawPartyColors.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(color: PawPartyColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: _profilePhotoPath != null
                    ? PawFileOrNetworkImage(
                        path: _profilePhotoPath!,
                        width: 120,
                        height: 120,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 32, color: PawPartyColors.textHint),
                          const SizedBox(height: 4),
                          Text(
                            'Add Photo',
                            style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Gallery & clips',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._galleryPhotos.map(
                (path) => Stack(
                  clipBehavior: Clip.none,
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
                      top: -4,
                      right: -4,
                      child: Material(
                        color: PawPartyColors.error,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _galleryPhotos.remove(path)),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ..._galleryVideos.map(
                (path) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => openFullscreenLocalVideo(context, path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: PawVideoThumbnail(path: path, height: 72),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Material(
                        color: PawPartyColors.error,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _galleryVideos.remove(path)),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('Photo'),
                onPressed: _addPetGalleryPhoto,
              ),
              ActionChip(
                avatar: const Icon(Icons.videocam, size: 18),
                label: const Text('Video'),
                onPressed: _addPetVideo,
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Pet Name',
              prefixIcon: Icon(Icons.pets),
            ),
          ),
          const SizedBox(height: 16),
          Text('Type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppConstants.petTypes.map((type) {
              final isSelected = _selectedType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedType = type),
                selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected ? PawPartyColors.primary : PawPartyColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Gender', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppConstants.petGenders.map((g) {
              final isSelected = _selectedGender == g;
              return ChoiceChip(
                label: Text(g),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedGender = g),
                selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected ? PawPartyColors.primary : PawPartyColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _breedController,
            decoration: const InputDecoration(
              labelText: 'Breed (optional)',
              prefixIcon: Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 16),
          Text('Size', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.sizeCategories.map((size) {
              final isSelected = _selectedSize == size;
              return ChoiceChip(
                label: Text(size),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedSize = size),
                selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected ? PawPartyColors.primary : PawPartyColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Age', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCounter(
                  'Years',
                  _ageYears,
                  0,
                  25,
                  (v) => setState(() => _ageYears = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCounter(
                  'Months',
                  _ageMonths,
                  0,
                  11,
                  (v) => setState(() => _ageMonths = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(
      String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PawPartyColors.divider),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 24),
                onPressed: value > min ? () => onChanged(value - 1) : null,
                color: PawPartyColors.primary,
              ),
              Text(
                '$value',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 24),
                onPressed: value < max ? () => onChanged(value + 1) : null,
                color: PawPartyColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Personality() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personality Profile', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'This helps us find the best matches',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          PersonalitySlider(
            label: 'Energy Level',
            value: _energyLevel,
            onChanged: (v) => setState(() => _energyLevel = v),
            lowLabel: 'Couch Potato',
            highLabel: 'Zoomies 24/7',
            icon: Icons.bolt,
            color: PawPartyColors.primary,
          ),
          const SizedBox(height: 28),
          PersonalitySlider(
            label: 'Social Comfort',
            value: _socialComfort,
            onChanged: (v) => setState(() => _socialComfort = v),
            lowLabel: 'Shy & Cautious',
            highLabel: 'Life of the Party',
            icon: Icons.people,
            color: PawPartyColors.secondary,
          ),
          const SizedBox(height: 28),
          PersonalitySlider(
            label: 'Kid Tolerance',
            value: _kidTolerance,
            onChanged: (v) => setState(() => _kidTolerance = v),
            lowLabel: 'Prefers Adults',
            highLabel: 'Loves Kids',
            icon: Icons.child_care,
            color: PawPartyColors.pizzaGold,
          ),
          const SizedBox(height: 28),
          PersonalitySlider(
            label: 'Size Tolerance',
            value: _sizeTolerance,
            onChanged: (v) => setState(() => _sizeTolerance = v),
            lowLabel: 'Same Size Only',
            highLabel: 'Any Size Friend',
            icon: Icons.straighten,
            color: PawPartyColors.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3PlayStyle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Play Style & Triggers', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'How does your pet like to play? What sets them off?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Play Styles', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Select all that apply',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.playStyles.map((style) {
              final isSelected = _selectedPlayStyles.contains(style);
              return FilterChip(
                label: Text(style),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPlayStyles.add(style);
                    } else {
                      _selectedPlayStyles.remove(style);
                    }
                  });
                },
                selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
                checkmarkColor: PawPartyColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? PawPartyColors.primary : PawPartyColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Text('Known Triggers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Helps us avoid bad matches',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.triggers.map((trigger) {
              final isSelected = _selectedTriggers.contains(trigger);
              return FilterChip(
                label: Text(trigger),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTriggers.add(trigger);
                    } else {
                      _selectedTriggers.remove(trigger);
                    }
                  });
                },
                selectedColor: PawPartyColors.error.withValues(alpha: 0.12),
                checkmarkColor: PawPartyColors.error,
                labelStyle: TextStyle(
                  color: isSelected ? PawPartyColors.error : PawPartyColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Bio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Almost Done!', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'A few last details to complete the profile',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Bio (optional)',
              hintText: 'What makes your pet special?',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.edit_note),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildToggle(
            'Spayed / Neutered',
            _isSpayedNeutered,
            (v) => setState(() => _isSpayedNeutered = v),
            Icons.healing,
          ),
          const SizedBox(height: 16),
          _buildToggle(
            'Vaccinations up to date',
            _isVaccinated,
            (v) => setState(() => _isVaccinated = v),
            Icons.vaccines,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PawPartyColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PawPartyColors.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: PawPartyColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your pet\'s profile will be visible to nearby members for matching.',
                    style: TextStyle(
                      fontSize: 13,
                      color: PawPartyColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PawPartyColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: PawPartyColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: PawPartyColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _saving ? null : () => _nextStep(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isLastStep ? PawPartyColors.success : PawPartyColors.primary,
          ),
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isLastStep ? 'Add to ${AppConstants.appName}!' : 'Continue'),
        ),
      ),
    );
  }
}
