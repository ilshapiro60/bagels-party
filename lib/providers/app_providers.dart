import 'dart:async' show TimeoutException, unawaited;

import 'package:flutter/foundation.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/auth_router_refresh.dart';
import '../config/firebase_bootstrap.dart';
import '../config/google_sign_in_init.dart';
import '../firebase_options.dart';
import '../models/meetup.dart';
import '../models/party_story.dart';
import '../models/passport_entry.dart';
import '../models/pet.dart';
import '../models/user_profile.dart';
import '../services/auth_persistence.dart';
import '../services/device_location_service.dart';
import '../services/firestore_pet_repository.dart';
import '../services/firestore_profile_repository.dart';
import '../services/firestore_retry.dart';
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
    if (!isFirebaseInitialized) return;
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null || fbUser.isAnonymous) return;
    try {
      await _applyAuthenticatedUser(fbUser).timeout(
        const Duration(seconds: 25),
      );
    } on TimeoutException catch (e, st) {
      debugPrint('restoreSession timed out: $e\n$st');
      await _clearStaleSessionAfterRestoreFailure();
    } catch (e, st) {
      debugPrint('restoreSession failed: $e\n$st');
      await _clearStaleSessionAfterRestoreFailure();
    }
  }

  /// Firebase user exists but Firestore/profile load failed; avoid infinite
  /// splash and let the user sign in again.
  Future<void> _clearStaleSessionAfterRestoreFailure() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await AuthPersistence.clear();
    ref.read(userPetsProvider.notifier).clear();
    state = const AuthState();
    authRouterRefresh.notifyAuthChanged();
  }

  Future<void> _applyAuthenticatedUser(User u) async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      state = state.copyWith(isLoading: false);
      throw StateError('Firebase is not configured.');
    }
    ref.read(userPetsProvider.notifier).clear();
    final profile = await firestoreRetry(() async {
      var p = await FirestoreProfileRepository.fetchOrCreate(u);
      p = await ProfilePersistence.mergeWithSaved(p);
      await FirestoreProfileRepository.saveProfile(p);
      await FirestoreProfileRepository.syncAcceptedInvitesForInviter(u.uid);
      final refreshed = await FirestoreProfileRepository.fetchProfile(u.uid);
      if (refreshed != null) {
        p = await ProfilePersistence.mergeWithSaved(refreshed);
        await FirestoreProfileRepository.saveProfile(p);
      }
      await ref.read(userPetsProvider.notifier).hydrate(p.id);
      return p;
    });
    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      user: profile,
    );
    await AuthPersistence.saveSession(
      email: profile.email,
      displayName: profile.displayName,
      authMethod: _authMethodLabel(u),
    );
    authRouterRefresh.notifyAuthChanged();
    Future.microtask(() => syncDeviceLocation());
  }

  Future<void> signIn(String email, String password) async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      throw StateError('Firebase is not configured.');
    }
    state = state.copyWith(isLoading: true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _applyAuthenticatedUser(cred.user!);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      throw StateError('Firebase is not configured.');
    }
    state = state.copyWith(isLoading: true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final trimmedName = name.trim();
      if (trimmedName.isNotEmpty) {
        await cred.user!.updateDisplayName(trimmedName);
        await cred.user!.reload();
      }
      final u = FirebaseAuth.instance.currentUser!;
      await _applyAuthenticatedUser(u);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Google uses Firebase + Google Sign-In. Apple is not implemented.
  Future<bool> signInWithSocial(String method) async {
    state = state.copyWith(isLoading: true);
    final key = method.toLowerCase();
    if (key == 'google') {
      try {
        return await _signInWithGoogle();
      } catch (_) {
        state = state.copyWith(isLoading: false);
        rethrow;
      }
    }
    if (key == 'apple') {
      state = state.copyWith(isLoading: false);
      throw UnsupportedError(
        'Apple Sign-In is not set up yet. Use Google or email.',
      );
    }
    state = state.copyWith(isLoading: false);
    throw UnsupportedError('Unknown sign-in method: $method');
  }

  Future<bool> _signInWithGoogle() async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      state = state.copyWith(isLoading: false);
      throw StateError(
        'Firebase is not configured. Run `flutterfire configure`.',
      );
    }

    await ensureGoogleSignInInitialized();

    final prior = FirebaseAuth.instance.currentUser;
    if (prior != null && prior.isAnonymous) {
      await FirebaseAuth.instance.signOut();
    }

    late final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'openid'],
      );
    } on GoogleSignInException catch (e) {
      state = state.copyWith(isLoading: false);
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return false;
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      state = state.copyWith(isLoading: false);
      throw StateError(
        'Google Sign-In did not return an ID token. Check Firebase Web client '
        'ID (serverClientId) and iOS URL scheme / GoogleService-Info.plist.',
      );
    }

    try {
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }

    final fbUser = FirebaseAuth.instance.currentUser!;
    await _applyAuthenticatedUser(fbUser);
    return true;
  }

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
    if (isFirebaseInitialized) {
      unawaited(
        FirestoreProfileRepository.updateLocation(
          uid: u.id,
          latitude: pos.latitude,
          longitude: pos.longitude,
          neighborhood: hood ?? u.neighborhood,
        ),
      );
    }
    return true;
  }

  Future<void> signOut() async {
    if (isFirebaseInitialized) {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && _signedInWithGoogle(u)) {
        await ensureGoogleSignInInitialized();
        await GoogleSignIn.instance.signOut();
      }
      await FirebaseAuth.instance.signOut();
    }
    await AuthPersistence.clear();
    state = const AuthState();
    ref.read(userPetsProvider.notifier).clear();
    authRouterRefresh.notifyAuthChanged();
  }

  void updateUser(UserProfile user) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(user: user);
    unawaited(ProfilePersistence.save(user));
    if (isFirebaseInitialized) {
      unawaited(FirestoreProfileRepository.saveProfile(user));
    }
  }

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

String _authMethodLabel(User u) {
  if (u.providerData.any((p) => p.providerId == 'google.com')) {
    return 'Google';
  }
  if (u.providerData.any((p) => p.providerId == 'apple.com')) {
    return 'Apple';
  }
  return 'email';
}

bool _signedInWithGoogle(User u) =>
    u.providerData.any((p) => p.providerId == 'google.com');

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
    List<String>? friendUids,
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
      friendUids: friendUids ?? this.friendUids,
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

  Future<void> hydrate(String? userId) async {
    if (userId == null || !isFirebaseInitialized) {
      state = [];
      return;
    }
    state = await FirestorePetRepository.loadForUser(userId);
  }

  void clear() {
    state = [];
  }

  Future<void> addPet(Pet pet) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    final owner = ref.read(authStateProvider).user;
    final anchored = FirestorePetRepository.withOwnerAnchor(pet, owner);
    await FirestorePetRepository.upsert(uid, anchored);
    state = [...state, anchored];
  }

  Future<void> removePet(String petId) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    await FirestorePetRepository.delete(uid, petId);
    state = state.where((p) => p.id != petId).toList();
  }

  Future<void> updatePet(Pet pet) async {
    final uid = ref.read(authStateProvider).user?.id;
    if (uid == null) return;
    final owner = ref.read(authStateProvider).user;
    final anchored = FirestorePetRepository.withOwnerAnchor(pet, owner);
    await FirestorePetRepository.upsert(uid, anchored);
    state = state.map((p) => p.id == pet.id ? anchored : p).toList();
  }
}

final communityPetsStreamProvider = StreamProvider<List<Pet>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (!isFirebaseInitialized || !auth.isAuthenticated || auth.user == null) {
    return Stream.value([]);
  }
  return FirestorePetRepository.watchCommunityPets(
    excludeOwnerId: auth.user!.id,
  );
});

/// Other users' pets (live). Empty until Firestore has data.
final nearbyPetsProvider = Provider<List<Pet>>((ref) {
  final async = ref.watch(communityPetsStreamProvider);
  return async.value ?? [];
});

final upcomingMeetupsProvider = Provider<List<Meetup>>((ref) {
  return const [];
});

final ownerProfileProvider =
    FutureProvider.family<UserProfile, String>((ref, ownerId) async {
  if (!isFirebaseInitialized) {
    return UserProfile.placeholderNeighbor(ownerId);
  }
  final p = await FirestoreProfileRepository.fetchProfile(ownerId);
  return p ?? UserProfile.placeholderNeighbor(ownerId);
});

final passportEntriesProvider =
    NotifierProvider<PassportNotifier, List<PassportEntry>>(
  PassportNotifier.new,
);

class PassportNotifier extends Notifier<List<PassportEntry>> {
  @override
  List<PassportEntry> build() => [];

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
  List<PartyStory> build() => [];

  void addStory(PartyStory story) {
    state = [story, ...state];
  }
}
