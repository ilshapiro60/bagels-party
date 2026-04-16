import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../config/map_platform.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/firebase_bootstrap.dart';
import '../../models/neighborhood_news.dart';
import '../../models/pet.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../utils/media_picker_utils.dart';
import '../../widgets/fullscreen_video.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_video_thumb.dart';
import '../../widgets/personality_slider.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_neighborhood_news_repository.dart';
import '../../services/firestore_pet_repository.dart';
import '../../services/vet_clinic_geocode.dart';
import '../vet_clinic_map_picker_screen.dart';

class CreatePetScreen extends ConsumerStatefulWidget {
  const CreatePetScreen({super.key, this.editPetId, this.initialPet});

  /// When set, screen loads that pet and saves with [updatePet] instead of create.
  final String? editPetId;
  final Pet? initialPet;

  @override
  ConsumerState<CreatePetScreen> createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends ConsumerState<CreatePetScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final _totalSteps = 4;

  /// Baseline doc when editing (preserves id, createdAt, ratings, map anchors).
  Pet? _baselinePet;
  bool _hydratedEdit = false;
  bool _editPetMissing = false;

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
  final _vetNameController = TextEditingController();
  final _vetAddressController = TextEditingController();
  double? _vetLat;
  double? _vetLng;
  String? _vetGooglePlaceId;
  bool _vetGeocoding = false;
  bool _isSpayedNeutered = false;
  bool _isVaccinated = false;
  bool _saving = false;

  static bool _isRemoteMedia(String path) {
    return FirestorePetRepository.isShareableMediaUrl(path);
  }

  static const _newsVideoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv', '.m4v'];

  static bool _isVideoMediaUrl(String url) {
    final lower = url.split('?').first.toLowerCase();
    return _newsVideoExtensions.any((ext) => lower.endsWith(ext));
  }

  static void _registerNewMediaForNewsletter(
    List<String> photoBucket,
    List<String> videoBucket,
    String url,
  ) {
    if (!FirestorePetRepository.isShareableMediaUrl(url)) return;
    if (_isVideoMediaUrl(url)) {
      if (videoBucket.length < 3) videoBucket.add(url);
    } else {
      if (photoBucket.length < 5) photoBucket.add(url);
    }
  }

  void _snackMediaUploadFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not upload media. Check your connection and try again. '
          'Only files saved to the cloud are visible to other pet parents on Discover.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _snackStorageFailed(Object e) {
    final detail = e is FirebaseException
        ? (e.message != null && e.message!.trim().isNotEmpty
            ? '${e.code}: ${e.message}'
            : e.code)
        : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not upload media ($detail). If the network is fine, deploy '
          'storage.rules and check App Check → Storage enforcement.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryHydrateEdit());
  }

  void _tryHydrateEdit() {
    final editId = widget.editPetId;
    if (editId == null || _hydratedEdit || _editPetMissing) return;

    Pet? pet = widget.initialPet;
    if (pet == null || pet.id != editId) {
      pet = null;
      for (final p in ref.read(userPetsProvider)) {
        if (p.id == editId) {
          pet = p;
          break;
        }
      }
    }

    if (pet == null) {
      if (ref.read(userPetsProvider).isNotEmpty) {
        setState(() => _editPetMissing = true);
      }
      return;
    }

    final user = ref.read(authStateProvider).user;
    if (user == null || pet.ownerId != user.id) {
      setState(() => _editPetMissing = true);
      return;
    }

    _applyPetToForm(pet);
    setState(() => _hydratedEdit = true);
  }

  void _applyPetToForm(Pet p) {
    _baselinePet = p;
    _nameController.text = p.name;
    _selectedType = AppConstants.petTypes.contains(p.type)
        ? p.type
        : AppConstants.petTypes.last;
    _selectedGender = AppConstants.petGenders.contains(p.gender)
        ? p.gender
        : AppConstants.petGenders[0];
    _breedController.text = p.breed ?? '';
    _selectedSize = AppConstants.sizeCategories.contains(p.size)
        ? p.size
        : AppConstants.sizeCategories[2];
    _ageYears = p.ageYears ?? 1;
    _ageMonths = p.ageMonths ?? 0;
    _profilePhotoPath = p.photoUrl;
    _galleryPhotos
      ..clear()
      ..addAll(p.photoGallery);
    _galleryVideos
      ..clear()
      ..addAll(p.videoPaths);
    _energyLevel = p.energyLevel;
    _socialComfort = p.socialComfort;
    _kidTolerance = p.kidTolerance;
    _sizeTolerance = p.sizeTolerance;
    _selectedPlayStyles
      ..clear()
      ..addAll(p.playStyles);
    _selectedTriggers
      ..clear()
      ..addAll(p.triggers);
    _bioController.text = p.bio ?? '';
    _vetNameController.text = p.vetClinicName ?? '';
    _vetAddressController.text = p.vetClinicAddress ?? '';
    _vetLat = p.vetClinicLatitude;
    _vetLng = p.vetClinicLongitude;
    _vetGooglePlaceId = p.vetGooglePlaceId;
    _isSpayedNeutered = p.isSpayedNeutered;
    _isVaccinated = p.isVaccinated;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _bioController.dispose();
    _vetNameController.dispose();
    _vetAddressController.dispose();
    super.dispose();
  }

  Future<void> _lookUpVetCoordinates() async {
    final addr = _vetAddressController.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a clinic address first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _vetGeocoding = true);
    try {
      final g = await tryGeocodeVetAddress(addr);
      if (!mounted) return;
      if (g == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No coordinates found. Try simplifying the address or check your connection.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _vetLat = g.lat;
        _vetLng = g.lng;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordinates saved for this clinic.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _vetGeocoding = false);
    }
  }

  void _onVetFieldsEdited() {
    setState(() {
      _vetGooglePlaceId = null;
      if (_vetNameController.text.trim().isEmpty) {
        _vetLat = null;
        _vetLng = null;
      }
    });
  }

  Future<void> _openVetMapPicker() async {
    if (!vetClinicMapPickerSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maps clinic picker is available on the iOS and Android apps.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final user = ref.read(authStateProvider).user;
    final picked = await openVetClinicMapPicker(
      context,
      fallbackLatitude: user?.latitude,
      fallbackLongitude: user?.longitude,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _vetNameController.text = picked.name;
      _vetAddressController.text = picked.address;
      _vetLat = picked.latitude;
      _vetLng = picked.longitude;
      _vetGooglePlaceId = picked.placeId;
    });
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
      _exitWizard();
    }
  }

  void _exitWizard() {
    if (!context.mounted) return;
    final editId = widget.editPetId;
    if (editId != null) {
      context.pop();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
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
    final isEdit = _baselinePet != null;
    if (isEdit && _baselinePet!.ownerId != user.id) return;

    setState(() => _saving = true);
    try {
      final storage = FirebaseStorageService.instance;
      final petId = isEdit ? _baselinePet!.id : const Uuid().v4();
      final newNewsletterPhotoUrls = <String>[];
      final newNewsletterVideoUrls = <String>[];

      String? photoUrl;
      final prof = _profilePhotoPath;
      if (prof != null && prof.isNotEmpty) {
        if (_isRemoteMedia(prof)) {
          photoUrl = prof;
        } else {
          try {
            final uploaded = await storage.uploadPetAvatar(
              localPath: prof,
              petId: petId,
              allowLocalFallback: false,
            );
            if (!FirestorePetRepository.isShareableMediaUrl(uploaded)) {
              if (!mounted) return;
              _snackMediaUploadFailed();
              return;
            }
            photoUrl = uploaded;
            _registerNewMediaForNewsletter(
              newNewsletterPhotoUrls,
              newNewsletterVideoUrls,
              uploaded,
            );
          } on FirebaseException catch (e) {
            if (!mounted) return;
            _snackStorageFailed(e);
            return;
          } catch (e) {
            if (!mounted) return;
            _snackStorageFailed(e);
            return;
          }
        }
      } else if (isEdit) {
        photoUrl = _baselinePet!.photoUrl;
      }

      final photoGallery = <String>[];
      for (final path in _galleryPhotos) {
        if (_isRemoteMedia(path)) {
          photoGallery.add(path);
        } else {
          try {
            final uploaded = await storage.uploadPetGalleryPhoto(
              localPath: path,
              petId: petId,
              allowLocalFallback: false,
            );
            if (!FirestorePetRepository.isShareableMediaUrl(uploaded)) {
              if (!mounted) return;
              _snackMediaUploadFailed();
              return;
            }
            photoGallery.add(uploaded);
            _registerNewMediaForNewsletter(
              newNewsletterPhotoUrls,
              newNewsletterVideoUrls,
              uploaded,
            );
          } on FirebaseException catch (e) {
            if (!mounted) return;
            _snackStorageFailed(e);
            return;
          } catch (e) {
            if (!mounted) return;
            _snackStorageFailed(e);
            return;
          }
        }
      }
      final videoPaths = <String>[];
      for (final path in _galleryVideos) {
        if (_isRemoteMedia(path)) {
          videoPaths.add(path);
        } else {
          try {
            final uploaded = await storage.uploadPetVideo(
              localPath: path,
              petId: petId,
              allowLocalFallback: false,
            );
            if (!FirestorePetRepository.isShareableMediaUrl(uploaded)) {
              if (!mounted) return;
              _snackMediaUploadFailed();
              return;
            }
            videoPaths.add(uploaded);
            _registerNewMediaForNewsletter(
              newNewsletterPhotoUrls,
              newNewsletterVideoUrls,
              uploaded,
            );
          } on FirebaseException catch (e) {
            if (!mounted) return;
            _snackStorageFailed(e);
            return;
          } catch (e) {
            if (!mounted) return;
            _snackStorageFailed(e);
            return;
          }
        }
      }

      final vetName = _vetNameController.text.trim();
      final vetAddr = _vetAddressController.text.trim();
      var vetLat = _vetLat;
      var vetLng = _vetLng;
      if (vetName.isNotEmpty &&
          vetAddr.isNotEmpty &&
          (vetLat == null || vetLng == null)) {
        final g = await tryGeocodeVetAddress(vetAddr);
        if (g != null) {
          vetLat = g.lat;
          vetLng = g.lng;
          if (mounted) {
            setState(() {
              _vetLat = vetLat;
              _vetLng = vetLng;
            });
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vet clinic saved without map coordinates — address could not be located.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
        createdAt: isEdit ? _baselinePet!.createdAt : DateTime.now(),
        meetupCount: isEdit ? _baselinePet!.meetupCount : 0,
        averageRating: isEdit ? _baselinePet!.averageRating : 0.0,
        ownerApproxLat: isEdit ? _baselinePet!.ownerApproxLat : null,
        ownerApproxLng: isEdit ? _baselinePet!.ownerApproxLng : null,
        vetClinicName: vetName.isEmpty ? null : vetName,
        vetClinicAddress: vetName.isEmpty
            ? null
            : (vetAddr.isEmpty ? null : vetAddr),
        vetClinicLatitude: vetName.isEmpty ? null : vetLat,
        vetClinicLongitude: vetName.isEmpty ? null : vetLng,
        vetGooglePlaceId: vetName.isEmpty ? null : _vetGooglePlaceId,
      );

      if (isEdit) {
        await ref.read(userPetsProvider.notifier).updatePet(pet);
      } else {
        await ref.read(userPetsProvider.notifier).addPet(pet);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? "${pet.name}'s profile was updated"
                : '${pet.name} has joined ${AppConstants.appName}! 🎉',
          ),
          backgroundColor: PawPartyColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await _publishNewPetMediaToAreaNewsletter(
        user: user,
        pet: pet,
        photoUrls: newNewsletterPhotoUrls,
        videoUrls: newNewsletterVideoUrls,
      );

      if (isEdit) {
        if (mounted) context.pop();
      } else {
        if (mounted) context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// When the owner uploads new photos/videos for a pet, mirror them to the Area newsletter.
  Future<void> _publishNewPetMediaToAreaNewsletter({
    required UserProfile user,
    required Pet pet,
    required List<String> photoUrls,
    required List<String> videoUrls,
  }) async {
    if (!isFirebaseInitialized) return;
    if (photoUrls.isEmpty && videoUrls.isEmpty) return;
    if (user.neighborhoodKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pet saved. Set your neighborhood in Profile to share new pet media on the Area newsletter.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final parts = user.displayName.trim().split(RegExp(r'\s+'));
    final first = parts.firstWhere((s) => s.isNotEmpty, orElse: () => 'A neighbor');
    final mediaKind = photoUrls.isNotEmpty && videoUrls.isNotEmpty
        ? 'photos and a video'
        : (photoUrls.isNotEmpty ? 'photos' : 'a video clip');
    final body = '$first added new $mediaKind of ${pet.name} (${pet.type}).';

    try {
      await FirestoreNeighborhoodNewsRepository.createPost(
        author: user,
        title: '${pet.name} — new media',
        body: body,
        category: NewsCategory.general.id,
        photoUrls: photoUrls,
        videoUrls: videoUrls,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pet saved; Area newsletter post failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    try {
      final path = source == ImageSource.gallery
          ? await pickPhotoFromGallery()
          : await pickPhotoFromCamera();
      if (path != null && mounted) setState(() => _profilePhotoPath = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    try {
      final path = source == ImageSource.gallery
          ? await pickPhotoFromGallery()
          : await pickPhotoFromCamera();
      if (path != null && mounted) setState(() => _galleryPhotos.add(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    try {
      final path = useCamera
          ? await pickVideoFromCamera()
          : await pickVideoFromGallery();
      if (path != null && mounted) setState(() => _galleryVideos.add(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add video: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Pet>>(userPetsProvider, (prev, next) {
      if (widget.editPetId != null && !_hydratedEdit && !_editPetMissing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryHydrateEdit());
      }
    });

    if (widget.editPetId != null && _editPetMissing) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.go('/home'),
          ),
          title: const Text('Edit pet'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This pet isn\'t in your account or you don\'t have access.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.editPetId != null && !_hydratedEdit) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _exitWizard,
          ),
          title: const Text('Edit pet'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.editPetId != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _previousStep,
        ),
        title: Text(isEdit ? 'Edit pet' : 'Add Your Pet'),
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
          const SizedBox(height: 8),
          Center(
            child: Text(
              'A new profile photo you save is also shared on the Area newsletter when your neighborhood is set.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: PawPartyColors.textHint, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Gallery & clips',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'New photos and videos you upload here are also posted to the Area newsletter when your neighborhood is set in Profile.',
            style: TextStyle(fontSize: 12, color: PawPartyColors.textHint, height: 1.35),
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
    final iconStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: Size.zero,
      padding: const EdgeInsets.all(6),
      visualDensity: VisualDensity.compact,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
            children: [
              IconButton(
                style: iconStyle,
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                onPressed: value > min ? () => onChanged(value - 1) : null,
                color: PawPartyColors.primary,
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                style: iconStyle,
                icon: const Icon(Icons.add_circle_outline, size: 22),
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
          const SizedBox(height: 28),
          Text(
            'Veterinary clinic (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _vetNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _onVetFieldsEdited(),
            decoration: const InputDecoration(
              labelText: 'Clinic name',
              hintText: 'Optional — visible like your pet on Discover',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vetAddressController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            onChanged: (_) => _onVetFieldsEdited(),
            decoration: const InputDecoration(
              labelText: 'Clinic address',
              hintText: 'Helps neighbors recognize the clinic',
            ),
          ),
          const SizedBox(height: 12),
          if (vetClinicMapPickerSupported)
            FilledButton.tonalIcon(
              onPressed: _openVetMapPicker,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Find clinic on map'),
            ),
          if (vetClinicMapPickerSupported) ...[
            const SizedBox(height: 8),
            Text(
              'Pick a clinic to save a Google Maps link for neighbors. You can still edit the text below.',
              style: TextStyle(
                fontSize: 12,
                color: PawPartyColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (_vetGooglePlaceId != null &&
              _vetNameController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: PawPartyColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Clinic linked for rich Google Maps (reviews & hours).',
                      style: TextStyle(
                        fontSize: 12,
                        color: PawPartyColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _vetGeocoding ? null : _lookUpVetCoordinates,
            icon: _vetGeocoding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.pin_drop_outlined),
            label: const Text('Look up coordinates'),
          ),
          if (_vetLat != null && _vetLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Coordinates: ${_vetLat!.toStringAsFixed(5)}, ${_vetLng!.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
              ),
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
              : Text(
                  isLastStep
                      ? (widget.editPetId != null
                          ? 'Save changes'
                          : 'Add to ${AppConstants.appName}!')
                      : 'Continue',
                ),
        ),
      ),
    );
  }
}
