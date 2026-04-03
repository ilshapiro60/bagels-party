import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/auth_router_refresh.dart';
import '../models/pet.dart';
import '../models/user_profile.dart';
import '../models/meetup.dart';
import '../models/passport_entry.dart';
import '../models/party_story.dart';
import '../services/auth_persistence.dart';
import '../services/device_location_service.dart';
import '../services/mock_data.dart';
import '../services/pet_persistence.dart';
import '../services/profile_persistence.dart';

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserProfile? user;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserProfile? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
    );
  }
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> restoreSession() async {
    final data = await AuthPersistence.loadSession();
    if (data == null) return;
    final base = MockData.currentUser.copyWith(
      email: data.email,
      displayName: data.displayName,
    );
    final user = await ProfilePersistence.mergeWithSaved(base);
    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      user: user,
    );
    authRouterRefresh.notifyAuthChanged();
    await ref.read(userPetsProvider.notifier).hydrate(state.user?.id);
    // GPS + reverse geocode can take seconds; don't block first frame / session ready.
    Future.microtask(() => syncDeviceLocation());
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(seconds: 1));
    final trimmed = email.trim();
    final user = await ProfilePersistence.mergeWithSaved(
      MockData.currentUser.copyWith(email: trimmed),
    );
    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      user: user,
    );
    await AuthPersistence.saveSession(
      email: state.user!.email,
      displayName: state.user!.displayName,
      authMethod: 'email',
    );
    authRouterRefresh.notifyAuthChanged();
    await ref.read(userPetsProvider.notifier).hydrate(state.user?.id);
    Future.microtask(() => syncDeviceLocation());
  }

  Future<void> signUp(String name, String email, String password) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(seconds: 1));
    final user = await ProfilePersistence.mergeWithSaved(
      MockData.currentUser.copyWith(displayName: name, email: email.trim()),
    );
    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      user: user,
    );
    await AuthPersistence.saveSession(
      email: state.user!.email,
      displayName: state.user!.displayName,
      authMethod: 'email',
    );
    authRouterRefresh.notifyAuthChanged();
    await ref.read(userPetsProvider.notifier).hydrate(state.user?.id);
    Future.microtask(() => syncDeviceLocation());
  }

  /// Mock Google / Apple — same as email sign-in for now, but tagged for persistence.
  Future<void> signInWithSocial(String method) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 800));
    final user = await ProfilePersistence.mergeWithSaved(MockData.currentUser);
    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      user: user,
    );
    await AuthPersistence.saveSession(
      email: state.user!.email,
      displayName: state.user!.displayName,
      authMethod: method,
    );
    authRouterRefresh.notifyAuthChanged();
    await ref.read(userPetsProvider.notifier).hydrate(state.user?.id);
    Future.microtask(() => syncDeviceLocation());
  }

  /// Requests permission and updates [AuthState.user] lat/lng + neighborhood label when possible.
  Future<bool> syncDeviceLocation() async {
    if (!state.isAuthenticated || state.user == null) return false;
    final pos = await DeviceLocationService.tryGetCurrentPosition();
    if (!state.isAuthenticated || state.user == null) return false;
    if (pos == null) return false;
    final hood = await DeviceLocationService.placemarkNeighborhood(
      pos.latitude,
      pos.longitude,
    );
    if (!state.isAuthenticated || state.user == null) return false;
    final u = state.user!;
    final updated = u.copyWithCoordinates(
      latitude: pos.latitude,
      longitude: pos.longitude,
      neighborhood: hood ?? u.neighborhood,
    );
    state = state.copyWith(user: updated);
    unawaited(ProfilePersistence.save(updated));
    return true;
  }

  Future<void> signOut() async {
    await AuthPersistence.clear();
    state = const AuthState();
    ref.read(userPetsProvider.notifier).clear();
    authRouterRefresh.notifyAuthChanged();
  }

  void updateUser(UserProfile user) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(user: user);
    unawaited(ProfilePersistence.save(user));
  }

  /// Keeps [AuthPersistence] in sync so the next cold start doesn’t restore an old display name.
  Future<void> updateDisplayName(String displayName) async {
    if (!state.isAuthenticated || state.user == null) return;
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return;
    final u = state.user!;
    updateUser(u.copyWithProfile(displayName: trimmed));
    final data = await AuthPersistence.loadSession();
    await AuthPersistence.saveSession(
      email: u.email,
      displayName: trimmed,
      authMethod: data?.authMethod ?? 'email',
    );
  }
}

extension UserProfileCopyWith on UserProfile {
  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    List<String>? ownerGalleryImagePaths,
    List<String>? ownerGalleryVideoPaths,
    String? neighborhood,
    double? latitude,
    double? longitude,
    List<String>? petIds,
    String? bio,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      ownerGalleryImagePaths:
          ownerGalleryImagePaths ?? this.ownerGalleryImagePaths,
      ownerGalleryVideoPaths:
          ownerGalleryVideoPaths ?? this.ownerGalleryVideoPaths,
      neighborhood: neighborhood ?? this.neighborhood,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      petIds: petIds ?? this.petIds,
      childAges: childAges,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      isHostPassActive: isHostPassActive,
      hostPassExpiry: hostPassExpiry,
      createdAt: createdAt,
      bio: bio ?? this.bio,
    );
  }
}

final userPetsProvider = NotifierProvider<PetsNotifier, List<Pet>>(
  PetsNotifier.new,
);

class PetsNotifier extends Notifier<List<Pet>> {
  @override
  List<Pet> build() => [];

  /// Load saved pets for [userId], or demo pets for that owner when nothing stored yet.
  Future<void> hydrate(String? userId) async {
    if (userId == null) {
      state = [];
      return;
    }
    state = await PetPersistence.load(userId);
  }

  void clear() {
    state = [];
  }

  Future<void> _persist() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) return;
    await PetPersistence.save(userId, state);
  }

  Future<void> addPet(Pet pet) async {
    state = [...state, pet];
    await _persist();
  }

  Future<void> removePet(String petId) async {
    state = state.where((p) => p.id != petId).toList();
    await _persist();
  }

  Future<void> updatePet(Pet pet) async {
    state = state.map((p) => p.id == pet.id ? pet : p).toList();
    await _persist();
  }
}

final nearbyPetsProvider = Provider<List<Pet>>((ref) {
  return MockData.nearbyPets;
});

final upcomingMeetupsProvider = Provider<List<Meetup>>((ref) {
  return MockData.upcomingMeetups;
});

final passportEntriesProvider =
    NotifierProvider<PassportNotifier, List<PassportEntry>>(
  PassportNotifier.new,
);

class PassportNotifier extends Notifier<List<PassportEntry>> {
  @override
  List<PassportEntry> build() => MockData.passportEntries;

  void addEntry(PassportEntry entry) {
    state = [entry, ...state];
  }
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(
  SelectedTabNotifier.new,
);

class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final partyStoriesProvider =
    NotifierProvider<PartyStoriesNotifier, List<PartyStory>>(
  PartyStoriesNotifier.new,
);

class PartyStoriesNotifier extends Notifier<List<PartyStory>> {
  @override
  List<PartyStory> build() => MockData.partyStories;

  void addStory(PartyStory story) {
    state = [story, ...state];
  }
}
