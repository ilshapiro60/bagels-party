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
  final List<String> childAges;
  final int hostCount;
  final int attendCount;
  final double hostRating;
  final double guestRating;
  final bool isHostPassActive;
  final DateTime? hostPassExpiry;
  final DateTime createdAt;
  final String? bio;

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
    this.childAges = const [],
    this.hostCount = 0,
    this.attendCount = 0,
    this.hostRating = 0.0,
    this.guestRating = 0.0,
    this.isHostPassActive = false,
    this.hostPassExpiry,
    required this.createdAt,
    this.bio,
  }) : neighborhoodKey = _effectiveNeighborhoodKey(neighborhoodKey, neighborhood);

  static String normalizeAreaKey(String? neighborhood) =>
      (neighborhood ?? '').trim().toLowerCase();

  static String _effectiveNeighborhoodKey(String? key, String? neighborhood) {
    final k = (key ?? '').trim().toLowerCase();
    if (k.isNotEmpty) return k;
    return normalizeAreaKey(neighborhood);
  }

  bool get canHostFree => hostCount < 3;
  bool get canHost => canHostFree || isHostPassActive;

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
      'childAges': childAges,
      'hostCount': hostCount,
      'attendCount': attendCount,
      'hostRating': hostRating,
      'guestRating': guestRating,
      'isHostPassActive': isHostPassActive,
      'hostPassExpiry': hostPassExpiry?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'bio': bio,
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
      childAges: List<String>.from(map['childAges'] ?? []),
      hostCount: map['hostCount'] as int? ?? 0,
      attendCount: map['attendCount'] as int? ?? 0,
      hostRating: (map['hostRating'] as num?)?.toDouble() ?? 0.0,
      guestRating: (map['guestRating'] as num?)?.toDouble() ?? 0.0,
      isHostPassActive: map['isHostPassActive'] as bool? ?? false,
      hostPassExpiry: map['hostPassExpiry'] != null
          ? DateTime.parse(map['hostPassExpiry'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      bio: map['bio'] as String?,
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
      childAges: childAges,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      isHostPassActive: isHostPassActive,
      hostPassExpiry: hostPassExpiry,
      createdAt: createdAt,
      bio: bio,
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
      childAges: childAges,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      isHostPassActive: isHostPassActive,
      hostPassExpiry: hostPassExpiry,
      createdAt: createdAt,
      bio: bio,
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
      childAges: childAges,
      hostCount: hostCount,
      attendCount: attendCount,
      hostRating: hostRating,
      guestRating: guestRating,
      isHostPassActive: isHostPassActive,
      hostPassExpiry: hostPassExpiry,
      createdAt: createdAt,
      bio: updateBio
          ? (bio == null || bio.isEmpty ? null : bio)
          : this.bio,
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
      childAges: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
