class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> ownerGalleryImagePaths;
  final List<String> ownerGalleryVideoPaths;
  final String? neighborhood;
  final double? latitude;
  final double? longitude;
  final List<String> petIds;
  final List<String> childAges;
  final int hostCount;
  final int attendCount;
  final double hostRating;
  final double guestRating;
  final bool isHostPassActive;
  final DateTime? hostPassExpiry;
  final DateTime createdAt;
  final String? bio;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.ownerGalleryImagePaths = const [],
    this.ownerGalleryVideoPaths = const [],
    this.neighborhood,
    this.latitude,
    this.longitude,
    this.petIds = const [],
    this.childAges = const [],
    this.hostCount = 0,
    this.attendCount = 0,
    this.hostRating = 0.0,
    this.guestRating = 0.0,
    this.isHostPassActive = false,
    this.hostPassExpiry,
    required this.createdAt,
    this.bio,
  });

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
      'latitude': latitude,
      'longitude': longitude,
      'petIds': petIds,
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
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      petIds: List<String>.from(map['petIds'] ?? []),
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
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
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
      latitude: latitude,
      longitude: longitude,
      petIds: petIds,
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
}
