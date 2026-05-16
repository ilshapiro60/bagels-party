import '../config/constants.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> ownerGalleryImagePaths;
  final List<String> ownerGalleryVideoPaths;
  final String? neighborhood;
  /// Lowercase trimmed [neighborhood]; used for area-scoped newsletter (Firestore rules).
  final String neighborhoodKey;
  /// Set to true in Firestore for moderator accounts (report queue).
  final bool isModerator;
  final double? latitude;
  final double? longitude;
  final List<String> petIds;
  /// UIDs of connected pet parents (paw buddy acceptances, etc.).
  final List<String> friendUids;
  final List<String> blockedUids;
  final int hostCount;
  final int attendCount;
  final double hostRating;
  final double guestRating;
  final DateTime createdAt;
  final String? bio;

  /// Business account fields (all optional, default false/null for regular users).
  final bool isBusinessAccount;
  final String? businessName;
  final String? businessCategory;
  final String? businessPlaceId;

  /// True while the user is actively checked in to appear on the nearby-pets map.
  /// Reset to false on every sign-in so users must opt-in each session.
  final bool isCheckedIn;

  /// True once the user has explicitly accepted the Terms of Service / EULA.
  final bool termsAccepted;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.ownerGalleryImagePaths = const [],
    this.ownerGalleryVideoPaths = const [],
    this.neighborhood,
    String? neighborhoodKey,
    this.isModerator = false,
    this.latitude,
    this.longitude,
    this.petIds = const [],
    this.friendUids = const [],
    this.blockedUids = const [],
    this.hostCount = 0,
    this.attendCount = 0,
    this.hostRating = 0.0,
    this.guestRating = 0.0,
    required this.createdAt,
    this.bio,
    this.isBusinessAccount = false,
    this.businessName,
    this.businessCategory,
    this.businessPlaceId,
    this.isCheckedIn = false,
    this.termsAccepted = false,
  }) : neighborhoodKey = _effectiveNeighborhoodKey(neighborhoodKey, neighborhood);

  static String normalizeAreaKey(String? neighborhood) =>
      (neighborhood ?? '').trim().toLowerCase();

  static String _effectiveNeighborhoodKey(String? key, String? neighborhood) {
    final k = (key ?? '').trim().toLowerCase();
    if (k.isNotEmpty) return k;
    return normalizeAreaKey(neighborhood);
  }

  bool get canHostFree => hostCount < AppConstants.maxFreeHostings;

  /// Profile photo + [ownerGalleryImagePaths], deduplicated — for fullscreen viewers.
  List<String> get ownerPhotoUrlsForViewer {
    final out = <String>[];
    void add(String? u) {
      final t = u?.trim();
      if (t == null || t.isEmpty) return;
      if (!out.contains(t)) out.add(t);
    }

    add(photoUrl);
    for (final path in ownerGalleryImagePaths) {
      add(path);
    }
    return out;
  }

  /// Display name for event cards -- prefers businessName for business accounts.
  String get eventHostDisplayName =>
      isBusinessAccount && businessName != null && businessName!.trim().isNotEmpty
          ? businessName!
          : displayName;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'ownerGalleryImagePaths': ownerGalleryImagePaths,
      'ownerGalleryVideoPaths': ownerGalleryVideoPaths,
      'neighborhood': neighborhood,
      'neighborhoodKey': neighborhoodKey,
      'isModerator': isModerator,
      'latitude': latitude,
      'longitude': longitude,
      'petIds': petIds,
      'friendUids': friendUids,
      'blockedUids': blockedUids,
      'hostCount': hostCount,
      'attendCount': attendCount,
      'hostRating': hostRating,
      'guestRating': guestRating,
      'createdAt': createdAt.toIso8601String(),
      'bio': bio,
      'isBusinessAccount': isBusinessAccount,
      'businessName': businessName,
      'businessCategory': businessCategory,
      'businessPlaceId': businessPlaceId,
      'isCheckedIn': isCheckedIn,
      'termsAccepted': termsAccepted,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      photoUrl: map['photoUrl'] as String?,
      ownerGalleryImagePaths:
          List<String>.from(map['ownerGalleryImagePaths'] ?? []),
      ownerGalleryVideoPaths:
          List<String>.from(map['ownerGalleryVideoPaths'] ?? []),
      neighborhood: map['neighborhood'] as String?,
      neighborhoodKey: _effectiveNeighborhoodKey(
        map['neighborhoodKey'] as String?,
        map['neighborhood'] as String?,
      ),
      isModerator: map['isModerator'] as bool? ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      petIds: List<String>.from(map['petIds'] ?? []),
      friendUids: List<String>.from(map['friendUids'] ?? []),
      blockedUids: List<String>.from(map['blockedUids'] ?? []),
      hostCount: map['hostCount'] as int? ?? 0,
      attendCount: map['attendCount'] as int? ?? 0,
      hostRating: (map['hostRating'] as num?)?.toDouble() ?? 0.0,
      guestRating: (map['guestRating'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      bio: map['bio'] as String?,
      isBusinessAccount: map['isBusinessAccount'] as bool? ?? false,
      businessName: map['businessName'] as String?,
      businessCategory: map['businessCategory'] as String?,
      businessPlaceId: map['businessPlaceId'] as String?,
      isCheckedIn: map['isCheckedIn'] as bool? ?? false,
      termsAccepted: map['termsAccepted'] as bool? ?? false,
    );
  }

  /// Updates map/search coordinates (e.g. from device GPS).
  UserProfile copyWithCoordinates({
    required double latitude,
    required double longitude,
    String? neighborhood,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      ownerGalleryImagePaths: ownerGalleryImagePaths,
      ownerGalleryVideoPaths: ownerGalleryVideoPaths,
      neighborhood: neighborhood ?? this.neighborhood,
      neighborhoodKey: UserProfile.normalizeAreaKey(neighborhood ?? this.neighborhood),
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: bio,
      isBusinessAccount: isBusinessAccount,
      businessName: businessName,
      businessCategory: businessCategory,
      businessPlaceId: businessPlaceId,
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  UserProfile copyWithHostCount(int hostCount) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      ownerGalleryImagePaths: ownerGalleryImagePaths,
      ownerGalleryVideoPaths: ownerGalleryVideoPaths,
      neighborhood: neighborhood,
      neighborhoodKey: neighborhoodKey,
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: bio,
      isBusinessAccount: isBusinessAccount,
      businessName: businessName,
      businessCategory: businessCategory,
      businessPlaceId: businessPlaceId,
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  UserProfile copyWithProfile({
    String? displayName,
    String? email,
    String? photoUrl,
    List<String>? ownerGalleryImagePaths,
    List<String>? ownerGalleryVideoPaths,
    String? neighborhood,
    String? bio,
    /// When true, [bio] replaces the current value (use `null` or empty to clear).
    bool updateBio = false,
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
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: updateBio
          ? (bio == null || bio.isEmpty ? null : bio)
          : this.bio,
      isBusinessAccount: isBusinessAccount,
      businessName: businessName,
      businessCategory: businessCategory,
      businessPlaceId: businessPlaceId,
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  UserProfile copyWithBusiness({
    required bool isBusinessAccount,
    String? businessName,
    String? businessCategory,
    String? businessPlaceId,
    bool clearBusinessFields = false,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      ownerGalleryImagePaths: ownerGalleryImagePaths,
      ownerGalleryVideoPaths: ownerGalleryVideoPaths,
      neighborhood: neighborhood,
      neighborhoodKey: neighborhoodKey,
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: bio,
      isBusinessAccount: isBusinessAccount,
      businessName: clearBusinessFields ? null : (businessName ?? this.businessName),
      businessCategory: clearBusinessFields ? null : (businessCategory ?? this.businessCategory),
      businessPlaceId: clearBusinessFields ? null : (businessPlaceId ?? this.businessPlaceId),
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  UserProfile copyWithBlockedUids(List<String> blockedUids) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      ownerGalleryImagePaths: ownerGalleryImagePaths,
      ownerGalleryVideoPaths: ownerGalleryVideoPaths,
      neighborhood: neighborhood,
      neighborhoodKey: neighborhoodKey,
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: bio,
      isBusinessAccount: isBusinessAccount,
      businessName: businessName,
      businessCategory: businessCategory,
      businessPlaceId: businessPlaceId,
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  UserProfile copyWithCheckedIn(bool isCheckedIn) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      ownerGalleryImagePaths: ownerGalleryImagePaths,
      ownerGalleryVideoPaths: ownerGalleryVideoPaths,
      neighborhood: neighborhood,
      neighborhoodKey: neighborhoodKey,
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: bio,
      isBusinessAccount: isBusinessAccount,
      businessName: businessName,
      businessCategory: businessCategory,
      businessPlaceId: businessPlaceId,
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  UserProfile copyWithTermsAccepted(bool termsAccepted) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      ownerGalleryImagePaths: ownerGalleryImagePaths,
      ownerGalleryVideoPaths: ownerGalleryVideoPaths,
      neighborhood: neighborhood,
      neighborhoodKey: neighborhoodKey,
      isModerator: isModerator,
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
      friendUids: friendUids,
      blockedUids: blockedUids,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      createdAt: createdAt,
      bio: bio,
      isBusinessAccount: isBusinessAccount,
      businessName: businessName,
      businessCategory: businessCategory,
      businessPlaceId: businessPlaceId,
      isCheckedIn: isCheckedIn,
      termsAccepted: termsAccepted,
    );
  }

  /// Minimal profile when another user has not written their Firestore doc yet.
  factory UserProfile.placeholderNeighbor(String ownerId) {
    return UserProfile(
      id: ownerId,
      email: '',
      displayName: 'Pet parent',
      neighborhood: 'Nearby',
      neighborhoodKey: UserProfile.normalizeAreaKey('Nearby'),
      petIds: const [],
      friendUids: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
