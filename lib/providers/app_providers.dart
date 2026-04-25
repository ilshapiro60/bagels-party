import 'dart:async' show TimeoutException, unawaited;
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/auth_router_refresh.dart';
import '../config/cloud_functions_region.dart';
import '../config/firebase_bootstrap.dart';
import '../config/google_sign_in_init.dart';
import '../firebase_options.dart';
import '../models/meetup.dart';
import '../models/party_invite.dart';
import '../models/pet_buddy_owner_mute.dart';
import '../models/pet_buddy_request.dart';
import '../models/journal_comment.dart';
import '../models/reaction.dart';
import '../models/passport_entry.dart';
import '../models/community_vet_clinic.dart';
import '../models/chat_safety_report.dart';
import '../models/neighborhood_news.dart';
import '../models/pet.dart';
import '../models/user_profile.dart';
import '../services/approximate_location.dart';
import '../services/auth_persistence.dart';
import '../services/device_location_service.dart';
import '../services/firebase_user_mapper.dart';
import '../models/direct_message.dart';
import '../models/party_album_item.dart';
import '../services/firestore_party_album_repository.dart';
import '../services/firestore_reaction_repository.dart';
import '../services/firestore_meetup_repository.dart';
import '../services/firestore_message_repository.dart';
import '../services/firestore_passport_repository.dart';
import '../services/firestore_pet_buddy_repository.dart';
import '../services/firestore_chat_safety_repository.dart';
import '../services/firestore_neighborhood_news_repository.dart';
import '../services/firestore_pet_repository.dart';
import '../services/firestore_profile_repository.dart';
import '../services/firestore_retry.dart';
import '../services/profile_persistence.dart';
import '../services/push_notification_service.dart';

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

    await _prepareGoogleSessionIfNeeded(fbUser);

    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      debugPrint('Token refresh at restore: $e');
    }
    final liveUser = FirebaseAuth.instance.currentUser;
    if (liveUser == null || liveUser.isAnonymous) return;

    try {
      await _applyAuthenticatedUser(liveUser).timeout(
        const Duration(seconds: 35),
      );
    } on TimeoutException catch (e, st) {
      debugPrint('restoreSession timed out: $e\n$st');
      await _applyRestoredSessionOfflineFallback(liveUser);
    } catch (e, st) {
      debugPrint('restoreSession failed: $e\n$st');
      if (_isTransientRestoreFailure(e)) {
        await _applyRestoredSessionOfflineFallback(liveUser);
      } else {
        await _clearStaleSessionAfterRestoreFailure();
      }
    }
  }

  /// Refreshes the Google Play layer so Firebase keeps a valid session on cold start.
  Future<void> _prepareGoogleSessionIfNeeded(User u) async {
    if (!_signedInWithGoogle(u)) return;
    try {
      await ensureGoogleSignInInitialized();
      final lightweightFuture =
          GoogleSignIn.instance.attemptLightweightAuthentication();
      if (lightweightFuture == null) return;
      final account = await lightweightFuture;
      final idToken = account?.authentication.idToken;
      if (idToken == null || idToken.isEmpty) return;
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } catch (e, st) {
      debugPrint('Google lightweight auth (non-fatal): $e\n$st');
    }
  }

  bool _isTransientRestoreFailure(Object e) {
    if (e is FirebaseException) {
      return e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'network-request-failed' ||
          e.code == 'internal';
    }
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network') && s.contains('unavailable');
  }

  /// Keeps Firebase signed in and uses cached profile / Auth shell so users are
  /// not forced through Google sign-in again after a slow or flaky Firestore read.
  Future<void> _applyRestoredSessionOfflineFallback(User u) async {
    try {
      ref.read(userPetsProvider.notifier).clear();
      UserProfile profile;
      final cached = await ProfilePersistence.load(u.uid);
      if (cached != null && cached.id == u.uid) {
        profile = await ProfilePersistence.mergeWithSaved(cached);
        final shell = userProfileFromFirebaseUser(u);
        profile = profile.copyWithProfile(
          email: shell.email,
          displayName: shell.displayName.trim().isNotEmpty
              ? shell.displayName
              : profile.displayName,
          photoUrl: shell.photoUrl ?? profile.photoUrl,
        );
      } else {
        profile = userProfileFromFirebaseUser(u);
        profile = await ProfilePersistence.mergeWithSaved(profile);
      }
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: profile,
      );
      unawaited(ProfilePersistence.save(profile));
      await AuthPersistence.saveSession(
        email: profile.email,
        displayName: profile.displayName,
        authMethod: _authMethodLabel(u),
      );
      authRouterRefresh.notifyAuthChanged();
      try {
        await ref.read(userPetsProvider.notifier).hydrate(profile.id);
      } catch (e, st) {
        debugPrint('Pet hydrate in offline fallback: $e\n$st');
      }
      unawaited(_retryFullProfileSync(u));
    } catch (e, st) {
      debugPrint('Offline session fallback failed: $e\n$st');
      await _clearStaleSessionAfterRestoreFailure();
    }
  }

  Future<void> _retryFullProfileSync(User u) async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (FirebaseAuth.instance.currentUser?.uid != u.uid) return;
    try {
      await _applyAuthenticatedUser(FirebaseAuth.instance.currentUser!);
    } catch (e) {
      debugPrint('Background profile sync: $e');
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
      await FirestoreProfileRepository.syncFriendsFromAcceptedPetBuddyRequests(
        u.uid,
      );
      await FirestoreProfileRepository.pruneStaleFriendUids(u.uid);
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
    unawaited(PushNotificationService.initialize(profile.id));
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

  /// Sends Firebase’s password-reset email to [email] (user taps link in inbox).
  Future<void> sendPasswordResetEmail(String email) async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      throw StateError('Firebase is not configured.');
    }
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw ArgumentError('Enter a valid email address first.');
    }
    state = state.copyWith(isLoading: true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: trimmed);
    } finally {
      if (!state.isAuthenticated) {
        state = state.copyWith(isLoading: false);
      }
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
      try {
        return await _signInWithApple();
      } catch (_) {
        state = state.copyWith(isLoading: false);
        rethrow;
      }
    }
    state = state.copyWith(isLoading: false);
    throw UnsupportedError('Unknown sign-in method: $method');
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<bool> _signInWithApple() async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      state = state.copyWith(isLoading: false);
      throw StateError('Firebase is not configured. Run `flutterfire configure`.');
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    late final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.pawparty.pawParty.siwa',
          redirectUri: Uri.parse(
            'https://pawparty-app.firebaseapp.com/__/auth/handler',
          ),
        ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      state = state.copyWith(isLoading: false);
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }

    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      state = state.copyWith(isLoading: false);
      throw StateError('Apple Sign-In did not return an identity token.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );

    try {
      final prior = FirebaseAuth.instance.currentUser;
      if (prior != null && prior.isAnonymous) {
        await FirebaseAuth.instance.signOut();
      }
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }

    // Apple only sends name on the first sign-in — persist before profile fetch.
    final fbUser = FirebaseAuth.instance.currentUser!;
    final given = appleCredential.givenName;
    final family = appleCredential.familyName;
    if ((given != null || family != null) &&
        (fbUser.displayName == null || fbUser.displayName!.isEmpty)) {
      final fullName = '${given ?? ''} ${family ?? ''}'.trim();
      if (fullName.isNotEmpty) {
        await fbUser.updateDisplayName(fullName);
        await fbUser.reload();
      }
    }

    await _applyAuthenticatedUser(FirebaseAuth.instance.currentUser!);
    return true;
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
    await PushNotificationService.clearTokenAndDispose();
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

  /// Deletes the signed-in account server-side (Firestore, Storage, Auth), then signs out locally.
  Future<void> deleteAccount() async {
    if (!DefaultFirebaseOptions.isConfigured || !isFirebaseInitialized) {
      throw StateError('Firebase is not configured.');
    }
    state = state.copyWith(isLoading: true);
    try {
      final callable = pawPartyFirebaseFunctions().httpsCallable('deleteMyAccount');
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(isLoading: false);
      final code = e.code.toLowerCase();
      if (code == 'not-found') {
        throw Exception(
          'Account deletion is not available yet: the deleteMyAccount cloud '
          'function was not found. Deploy it to us-central1 (same region as '
          'your other callables), then try again.',
        );
      }
      final msg = e.message?.trim();
      if (msg != null && msg.isNotEmpty) {
        throw Exception(msg);
      }
      throw Exception(e.code);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
    await signOut();
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
    bool? isModerator,
    double? latitude,
    double? longitude,
    List<String>? petIds,
    List<String>? friendUids,
    String? bio,
  }) {
    final nextHood = neighborhood ?? this.neighborhood;
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      ownerGalleryImagePaths:
          ownerGalleryImagePaths ?? this.ownerGalleryImagePaths,
      ownerGalleryVideoPaths:
          ownerGalleryVideoPaths ?? this.ownerGalleryVideoPaths,
      neighborhood: nextHood,
      neighborhoodKey: UserProfile.normalizeAreaKey(nextHood),
      isModerator: isModerator ?? this.isModerator,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      petIds: petIds ?? this.petIds,
      friendUids: friendUids ?? this.friendUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
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
    final synced = FirestorePetRepository.petWithShareableMediaOnly(anchored);
    state = [...state, synced];
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
    final synced = FirestorePetRepository.petWithShareableMediaOnly(anchored);
    state = state.map((p) => p.id == pet.id ? synced : p).toList();
  }
}

/// Each friend's pets with a label for the owner (for connection invites).
/// Only users in [UserProfile.friendUids] are included.
final friendsPetInviteOptionsProvider =
    FutureProvider<List<(Pet pet, String ownerLabel)>>((ref) async {
  final user = ref.watch(authStateProvider).user;
  if (user == null || !isFirebaseInitialized) return [];
  final friendUids = user.friendUids.toSet();
  if (friendUids.isEmpty) return [];
  final out = <(Pet, String)>[];
  for (final uid in friendUids) {
    final profile = await FirestoreProfileRepository.fetchProfile(uid);
    final label = profile != null && profile.displayName.trim().isNotEmpty
        ? profile.displayName
        : 'Friend';
    final pets = await FirestorePetRepository.loadForUser(uid);
    for (final p in pets) {
      out.add((p, label));
    }
  }
  out.sort(
    (a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()),
  );
  return out;
});

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

/// Deduped vet clinics from your pets plus neighbors' pets; sorted by link count, then distance.
final communityVetClinicsProvider = Provider<List<CommunityVetClinic>>((ref) {
  final mine = ref.watch(userPetsProvider);
  final neighbors = ref.watch(nearbyPetsProvider);
  final pets = [...mine, ...neighbors];
  final user = ref.watch(authStateProvider).user;
  final list = CommunityVetClinic.aggregateFromPets(pets);

  double? distanceMeters(CommunityVetClinic c) {
    final ulat = user?.latitude;
    final ulng = user?.longitude;
    if (ulat == null || ulng == null) return null;
    final plat = c.latitude;
    final plng = c.longitude;
    if (plat == null || plng == null) return null;
    return haversineMeters(
      GeoPoint(ulat, ulng),
      GeoPoint(plat, plng),
    );
  }

  list.sort((a, b) {
    final byCount = b.linkCount.compareTo(a.linkCount);
    if (byCount != 0) return byCount;
    final da = distanceMeters(a);
    final db = distanceMeters(b);
    if (da == null && db == null) {
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    }
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return list;
});

/// Area newsletter posts (last 30 days) for the signed-in user's [UserProfile.neighborhoodKey].
final neighborhoodNewsPostsProvider =
    StreamProvider<List<NeighborhoodNewsPost>>((ref) {
  final user = ref.watch(authStateProvider).user;
  if (user == null || !isFirebaseInitialized) {
    return Stream.value([]);
  }
  return FirestoreNeighborhoodNewsRepository.watchPostsForArea(
    areaKey: user.neighborhoodKey,
  );
});

/// Moderator-only: pending content reports (empty stream if not moderator).
final neighborhoodNewsPendingReportsProvider =
    StreamProvider<List<NeighborhoodNewsReport>>((ref) {
  final user = ref.watch(authStateProvider).user;
  if (user == null ||
      !user.isModerator ||
      !isFirebaseInitialized) {
    return Stream.value([]);
  }
  return FirestoreNeighborhoodNewsRepository.watchPendingReports();
});

/// Moderator-only: pending private message / conduct reports.
final chatSafetyPendingReportsProvider =
    StreamProvider<List<ChatSafetyReport>>((ref) {
  final user = ref.watch(authStateProvider).user;
  if (user == null ||
      !user.isModerator ||
      !isFirebaseInitialized) {
    return Stream.value([]);
  }
  return FirestoreChatSafetyRepository.watchPendingReports();
});

final neighborhoodNewsCommentsProvider = StreamProvider.family<
    List<NeighborhoodNewsComment>,
    String>((ref, postId) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestoreNeighborhoodNewsRepository.watchComments(postId);
});

final upcomingMeetupsProvider = StreamProvider<List<Meetup>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestoreMeetupRepository.watchHostedBy(uid);
});

final incomingPartyInvitesProvider =
    StreamProvider<List<PartyInvite>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestoreMeetupRepository.watchIncomingInvites(uid);
});

/// Invites to parties that have not ended yet (excludes declined; cancelled meetups dropped).
Future<List<PartyInvite>> filterPartyInvitesToFutureParties(
  List<PartyInvite> invites,
) async {
  if (invites.isEmpty) return [];
  final ids = invites.map((e) => e.meetupId).toSet();
  final meetups = <String, Meetup?>{};
  for (final id in ids) {
    meetups[id] = await FirestoreMeetupRepository.fetchMeetup(id);
  }
  final out = <PartyInvite>[];
  for (final inv in invites) {
    if (inv.status == PartyInviteStatus.declined) continue;
    final m = meetups[inv.meetupId];
    if (m == null || m.status == MeetupStatus.cancelled || !m.hasNotEnded) {
      continue;
    }
    out.add(inv);
  }
  out.sort((a, b) {
    final ma = meetups[a.meetupId]!;
    final mb = meetups[b.meetupId]!;
    final byDate = ma.dateTime.compareTo(mb.dateTime);
    if (byDate != 0) return byDate;
    if (a.status == PartyInviteStatus.pending &&
        b.status != PartyInviteStatus.pending) {
      return -1;
    }
    if (b.status == PartyInviteStatus.pending &&
        a.status != PartyInviteStatus.pending) {
      return 1;
    }
    return b.sentAt.compareTo(a.sentAt);
  });
  return out;
}

/// Invitations the user can still act on or attend (party not ended).
final futureIncomingPartyInvitesProvider =
    StreamProvider<List<PartyInvite>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestoreMeetupRepository.watchIncomingInvites(uid).asyncMap(
    filterPartyInvitesToFutureParties,
  );
});

/// Hosted parties that have not ended yet, soonest first.
final futureHostedMeetupsProvider = Provider<AsyncValue<List<Meetup>>>((ref) {
  return ref.watch(upcomingMeetupsProvider).when(
        data: (list) {
          final upcoming = list.where((m) => m.hasNotEnded).toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
          return AsyncValue.data(upcoming);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
});

/// All public / open events (for Discover Events tab). Client-side distance filter.
final publicMeetupsProvider = StreamProvider<List<Meetup>>((ref) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestoreMeetupRepository.watchPublicMeetups();
});

/// Party invites for a meetup (host-only query shape for Firestore rules).
final partyInvitesForHostedMeetupProvider = StreamProvider.family<
    List<PartyInvite>,
    ({String meetupId, String hostId})>((ref, args) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestoreMeetupRepository.watchInvitesForMeetupAsHost(
    meetupId: args.meetupId,
    hostId: args.hostId,
  );
});

/// Other pets linked to [petId] via `petBuddies` (for profile + Discover).
final buddyPetsForPetProvider = StreamProvider.family<List<Pet>, String>((
  ref,
  petId,
) {
  return FirestorePetBuddyRepository.watchEdgesForPet(petId).asyncMap((
    edges,
  ) async {
    final out = <Pet>[];
    for (final e in edges) {
      final p = await FirestorePetRepository.fetchPet(
        e.otherOwnerId,
        e.otherPetId,
      );
      if (p != null) out.add(p);
    }
    return out;
  });
});

final incomingPetBuddyRequestsProvider =
    StreamProvider<List<PetBuddyRequest>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestorePetBuddyRepository.watchIncomingPending(uid);
});

final outgoingPetBuddyRequestsProvider =
    StreamProvider<List<PetBuddyRequest>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestorePetBuddyRepository.watchOutgoingPending(uid);
});

/// Owner-level paw buddy blocks (see [FirestorePetBuddyRepository.muteBuddyOwners]).
final petBuddyOwnerMutesProvider =
    StreamProvider<List<PetBuddyOwnerMute>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestorePetBuddyRepository.watchMutesInvolving(uid);
});

final ownerProfileProvider =
    FutureProvider.family<UserProfile, String>((ref, ownerId) async {
  if (!isFirebaseInitialized) {
    return UserProfile.placeholderNeighbor(ownerId);
  }
  final p = await FirestoreProfileRepository.fetchProfile(ownerId);
  return p ?? UserProfile.placeholderNeighbor(ownerId);
});

/// Current user’s passport journal (Firestore).
final passportMyEntriesProvider = StreamProvider<List<PassportEntry>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) {
    return Stream.value([]);
  }
  return FirestorePassportRepository.watchMyEntries(uid);
});

/// Public entries from all users (searchable in the Community tab).
final passportPublicEntriesProvider = StreamProvider<List<PassportEntry>>((ref) {
  if (!isFirebaseInitialized) {
    return Stream.value([]);
  }
  return FirestorePassportRepository.watchPublicEntries();
});

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

/// All conversations for the current user (inbox).
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (!isFirebaseInitialized || uid == null) return Stream.value([]);
  return FirestoreMessageRepository.watchConversations(uid);
});

/// Whether the current user has any unread messages across all conversations.
final hasUnreadMessagesProvider = Provider<bool>((ref) {
  final uid = ref.watch(authStateProvider).user?.id;
  if (uid == null) return false;
  final convos = ref.watch(conversationsProvider).value ?? [];
  return convos.any((c) => c.hasUnread(uid));
});

/// Messages for a specific conversation (chat screen).
final messagesProvider =
    StreamProvider.family<List<DirectMessage>, String>((ref, conversationId) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestoreMessageRepository.watchMessages(conversationId);
});

/// Shared party album photos for a specific meetup.
final partyAlbumProvider =
    StreamProvider.family<List<PartyAlbumItem>, String>((ref, meetupId) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestorePartyAlbumRepository.watchAlbumForMeetup(meetupId);
});

/// Comments on a public journal entry.
final journalCommentsProvider =
    StreamProvider.family<List<JournalComment>, String>((ref, entryId) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestorePassportRepository.watchComments(entryId);
});

/// Emoji reactions for any target (post ID, media URL hash, etc.).
final reactionsProvider =
    StreamProvider.family<List<ItemReaction>, String>((ref, targetId) {
  if (!isFirebaseInitialized) return Stream.value([]);
  return FirestoreReactionRepository.watchReactions(targetId);
});
