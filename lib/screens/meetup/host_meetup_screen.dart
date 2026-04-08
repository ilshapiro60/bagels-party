import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../config/constants.dart';
import '../../config/firebase_bootstrap.dart';
import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../providers/app_providers.dart';
import '../../services/approximate_location.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../widgets/host_venue_map.dart';
import '../../widgets/pizza_commitment.dart';

class HostMeetupScreen extends ConsumerStatefulWidget {
  const HostMeetupScreen({super.key});

  @override
  ConsumerState<HostMeetupScreen> createState() => _HostMeetupScreenState();
}

class _HostMeetupScreenState extends ConsumerState<HostMeetupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Event details
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedTheme = AppConstants.eventThemes[0];
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  int _duration = 120;

  // Step 2: Location & amenities
  final _addressController = TextEditingController();
  final _venueNameController = TextEditingController();
  bool _isPublic = false;
  int _maxGuests = 20;
  bool _hasYard = false;
  bool _hasPool = false;
  bool _kidFriendly = true;

  // Step 3: Pizza commitment
  bool _willProvidePizza = false;
  bool _willProvideDrinks = false;
  bool _willAccommodateAllergies = false;
  bool _acknowledgesHostDuty = false;
  bool _creating = false;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _venueNameController.dispose();
    super.dispose();
  }

  bool _validateStep1ForContinue() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a party title to continue.')),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2ForContinue() {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add an address for your space to continue.'),
        ),
      );
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_validateStep1ForContinue()) return;
    } else if (_currentStep == 1) {
      if (!_validateStep2ForContinue()) return;
    } else {
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  void _onCreatePressed() {
    if (_creating) return;
    _createMeetup();
  }

  void _exitHostFlow() {
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
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
      _exitHostFlow();
    }
  }

  Future<void> _createMeetup() async {
    final title = _titleController.text.trim();
    final address = _addressController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a party title.')),
      );
      return;
    }
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an address for your space.')),
      );
      return;
    }
    if (!isFirebaseInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase is not configured - cannot save the party yet.'),
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    FocusScope.of(context).unfocus();

    setState(() => _creating = true);
    try {
      final when = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final lat = user.latitude ?? kFallbackMapLat;
      final lng = user.longitude ?? kFallbackMapLng;
      final myPetIds = ref.read(userPetsProvider).map((p) => p.id).toList();

      final venueName = _venueNameController.text.trim();
      final meetup = Meetup(
        id: const Uuid().v4(),
        hostId: user.id,
        hostName: user.eventHostDisplayName,
        hostPhotoUrl: user.photoUrl,
        title: title,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        theme: _selectedTheme,
        dateTime: when,
        durationMinutes: _duration,
        address: address,
        latitude: lat,
        longitude: lng,
        maxGuests: _isPublic ? _maxGuests : 0,
        invites: const [],
        pizzaCommitment: PizzaCommitment(
          willProvidePizza: _willProvidePizza,
          willProvideDrinks: _willProvideDrinks,
          willAccommodateAllergies: _willAccommodateAllergies,
          acknowledgesHostDuty: _acknowledgesHostDuty,
        ),
        status: MeetupStatus.open,
        hasYard: _hasYard,
        hasPool: _hasPool,
        kidFriendly: _kidFriendly,
        compatiblePetIds: myPetIds,
        createdAt: DateTime.now(),
        isPublic: _isPublic,
        venueName: venueName.isEmpty ? null : venueName,
      );

      await FirestoreMeetupRepository.createMeetup(meetup);
      await FirestoreProfileRepository.incrementHostCount(user.id);
      ref.read(authStateProvider.notifier).updateUser(
            user.copyWithHostCount(user.hostCount + 1),
          );

      if (!mounted) return;
      if (_isPublic) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Public event created! Nearby pet owners can now discover it.'),
            backgroundColor: PawPartyColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Party created! Now invite your friends.'),
            backgroundColor: PawPartyColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/invite-friends/${meetup.id}');
      }
    } catch (e) {
      if (!mounted) return;
      final es = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            es.contains('permission-denied')
                ? 'Permission denied saving the party. Deploy latest rules: '
                    'firebase deploy --only firestore:rules'
                : 'Could not create party: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _previousStep();
      },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _previousStep,
        ),
        title: const Text('Host a party'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_currentStep + 1}/3',
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
                _buildStep1Details(),
                _buildStep2Location(),
                _buildStep3Pizza(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: _buildBottomButton(),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / 3,
          backgroundColor: PawPartyColors.divider,
          valueColor: const AlwaysStoppedAnimation(PawPartyColors.primary),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildStep1Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event Details', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Set up your party',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Party Title',
              hintText: 'e.g., Sunday Afternoon Hangout',
              prefixIcon: Icon(Icons.celebration),
            ),
          ),
          const SizedBox(height: 16),
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.eventThemes.map((theme) {
              final isSelected = _selectedTheme == theme;
              return ChoiceChip(
                label: Text(theme),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedTheme = theme),
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
          TextFormField(
            controller: _descController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'What should guests expect?',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.description),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  'Date',
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                  Icons.calendar_today,
                  _selectDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  'Time',
                  _selectedTime.format(context),
                  Icons.access_time,
                  _selectTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Duration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [60, 90, 120, 150, 180].map((mins) {
              final isSelected = _duration == mins;
              return ChoiceChip(
                label: Text('${mins ~/ 60}h${mins % 60 > 0 ? " ${mins % 60}m" : ""}'),
                selected: isSelected,
                onSelected: (_) => setState(() => _duration = mins),
                selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PawPartyColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PawPartyColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: PawPartyColors.textSecondary),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Location() {
    final user = ref.watch(authStateProvider).user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Space', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Where will the party happen?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _amenityToggle(
            'Open to everyone nearby',
            Icons.public,
            _isPublic,
            (v) => setState(() => _isPublic = v),
          ),
          if (_isPublic) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PawPartyColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign, size: 16, color: PawPartyColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This event will appear on the Discover screen for all nearby pet owners.',
                      style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _venueNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Venue / Business Name',
                hintText: 'e.g., Riverside Pet Clinic',
                prefixIcon: Icon(Icons.storefront),
              ),
            ),
            const SizedBox(height: 16),
            Text('Guest limit', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.group, size: 20, color: PawPartyColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _maxGuests.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    activeColor: PawPartyColors.primary,
                    label: '$_maxGuests guests',
                    onChanged: (v) => setState(() => _maxGuests = v.round()),
                  ),
                ),
                Text(
                  '$_maxGuests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address',
              hintText: _isPublic ? 'Venue address' : 'Your home address',
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 8),
          if (!_isPublic)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PawPartyColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield, size: 16, color: PawPartyColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your exact address is only shared after guests accept your invite.',
                      style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text('Amenities', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _amenityToggle('Fenced Yard', Icons.fence, _hasYard, (v) => setState(() => _hasYard = v)),
          const SizedBox(height: 12),
          _amenityToggle('Pool / Water Feature', Icons.pool, _hasPool, (v) => setState(() => _hasPool = v)),
          const SizedBox(height: 12),
          _amenityToggle('Kid-Friendly Space', Icons.child_friendly, _kidFriendly, (v) => setState(() => _kidFriendly = v)),
          const SizedBox(height: 24),
          HostVenueMap(
            height: 200,
            anchorLatitude: user?.latitude,
            anchorLongitude: user?.longitude,
          ),
          const SizedBox(height: 8),
          Text(
            _isPublic
                ? 'Your venue location is visible to everyone on the Discover map.'
                : 'Guests see this general area until they accept your invite. Your street address stays private until then.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: PawPartyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amenityToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? PawPartyColors.primary.withValues(alpha: 0.3) : PawPartyColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? PawPartyColors.primary : PawPartyColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          Switch(value: value, onChanged: onChanged, activeThumbColor: PawPartyColors.primary),
        ],
      ),
    );
  }

  Widget _buildStep3Pizza() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The Pizza Promise', style: Theme.of(context).textTheme.headlineLarge)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'This is what makes ${AppConstants.appName} special',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          PizzaCommitmentWidget(
            willProvidePizza: _willProvidePizza,
            willProvideDrinks: _willProvideDrinks,
            willAccommodateAllergies: _willAccommodateAllergies,
            acknowledgesHostDuty: _acknowledgesHostDuty,
            onPizzaChanged: (v) => setState(() => _willProvidePizza = v),
            onDrinksChanged: (v) => setState(() => _willProvideDrinks = v),
            onAllergiesChanged: (v) => setState(() => _willAccommodateAllergies = v),
            onHostDutyChanged: (v) => setState(() => _acknowledgesHostDuty = v),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PawPartyColors.pizzaGold.withValues(alpha: 0.15),
                  PawPartyColors.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PawPartyColors.pizzaGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_pizza, size: 40, color: PawPartyColors.pizzaGold),
                const SizedBox(height: 12),
                Text(
                  'Order from a partner restaurant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '15% off your order when you host through a partner restaurant!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.storefront),
                  label: const Text('Browse Partners'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PawPartyColors.pizzaGold,
                    side: BorderSide(color: PawPartyColors.pizzaGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final isLastStep = _currentStep == 2;
    final pizzaComplete = _willProvidePizza &&
        _willProvideDrinks &&
        _willAccommodateAllergies &&
        _acknowledgesHostDuty;
    final canProceed =
        isLastStep ? pizzaComplete && !_creating : !_creating;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLastStep && !pizzaComplete)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'All four commitments are required to host',
                style: TextStyle(fontSize: 12, color: PawPartyColors.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canProceed
                  ? (isLastStep ? _onCreatePressed : _nextStep)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? PawPartyColors.success : PawPartyColors.primary,
              ),
              child: _creating && isLastStep
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isLastStep ? 'Create party!' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
