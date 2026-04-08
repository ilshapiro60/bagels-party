class Pet {
  final String id;
  final String ownerId;
  final String name;
  final String type;
  final String? breed;
  /// e.g. Female, Male, Prefer not to say
  final String gender;
  final String size;
  final int? ageYears;
  final int? ageMonths;
  final String? photoUrl;
  final List<String> photoGallery;
  /// Local file paths or remote URLs; from camera/gallery until Firebase Storage.
  final List<String> videoPaths;
  final double energyLevel;
  final double socialComfort;
  final double kidTolerance;
  final double sizeTolerance;
  final List<String> playStyles;
  final List<String> triggers;
  final String? bio;
  final bool isSpayedNeutered;
  final bool isVaccinated;
  final DateTime createdAt;
  final int meetupCount;
  final double averageRating;
  /// Owner's last known coords when the pet was saved (for Discover map fuzzing).
  final double? ownerApproxLat;
  final double? ownerApproxLng;
  /// Optional linked veterinary clinic (visible to other users like the rest of the pet profile).
  final String? vetClinicName;
  final String? vetClinicAddress;
  final double? vetClinicLatitude;
  final double? vetClinicLongitude;
  /// Reserved for future Google Places deduplication; optional.
  final String? vetGooglePlaceId;

  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.breed,
    this.gender = 'Prefer not to say',
    required this.size,
    this.ageYears,
    this.ageMonths,
    this.photoUrl,
    this.photoGallery = const [],
    this.videoPaths = const [],
    required this.energyLevel,
    required this.socialComfort,
    required this.kidTolerance,
    required this.sizeTolerance,
    this.playStyles = const [],
    this.triggers = const [],
    this.bio,
    this.isSpayedNeutered = false,
    this.isVaccinated = false,
    required this.createdAt,
    this.meetupCount = 0,
    this.averageRating = 0.0,
    this.ownerApproxLat,
    this.ownerApproxLng,
    this.vetClinicName,
    this.vetClinicAddress,
    this.vetClinicLatitude,
    this.vetClinicLongitude,
    this.vetGooglePlaceId,
  });

  bool get hasVetClinicLink =>
      vetClinicName != null && vetClinicName!.trim().isNotEmpty;

  String get ageDisplay {
    if (ageYears == null && ageMonths == null) return 'Unknown';
    final parts = <String>[];
    if (ageYears != null && ageYears! > 0) {
      parts.add('${ageYears}y');
    }
    if (ageMonths != null && ageMonths! > 0) {
      parts.add('${ageMonths}m');
    }
    return parts.join(' ');
  }

  String get energyLabel {
    if (energyLevel < 0.33) return 'Chill';
    if (energyLevel < 0.66) return 'Moderate';
    return 'High Energy';
  }

  String get socialLabel {
    if (socialComfort < 0.33) return 'Cautious';
    if (socialComfort < 0.66) return 'Warming Up';
    return 'Social Butterfly';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'type': type,
      'breed': breed,
      'gender': gender,
      'size': size,
      'ageYears': ageYears,
      'ageMonths': ageMonths,
      'photoUrl': photoUrl,
      'photoGallery': photoGallery,
      'videoPaths': videoPaths,
      'energyLevel': energyLevel,
      'socialComfort': socialComfort,
      'kidTolerance': kidTolerance,
      'sizeTolerance': sizeTolerance,
      'playStyles': playStyles,
      'triggers': triggers,
      'bio': bio,
      'isSpayedNeutered': isSpayedNeutered,
      'isVaccinated': isVaccinated,
      'createdAt': createdAt.toIso8601String(),
      'meetupCount': meetupCount,
      'averageRating': averageRating,
      'ownerApproxLat': ownerApproxLat,
      'ownerApproxLng': ownerApproxLng,
      'vetClinicName': vetClinicName,
      'vetClinicAddress': vetClinicAddress,
      'vetClinicLatitude': vetClinicLatitude,
      'vetClinicLongitude': vetClinicLongitude,
      'vetGooglePlaceId': vetGooglePlaceId,
    };
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      breed: map['breed'] as String?,
      gender: map['gender'] as String? ?? 'Prefer not to say',
      size: map['size'] as String,
      ageYears: map['ageYears'] as int?,
      ageMonths: map['ageMonths'] as int?,
      photoUrl: map['photoUrl'] as String?,
      photoGallery: List<String>.from(map['photoGallery'] ?? []),
      videoPaths: List<String>.from(map['videoPaths'] ?? []),
      energyLevel: (map['energyLevel'] as num).toDouble(),
      socialComfort: (map['socialComfort'] as num).toDouble(),
      kidTolerance: (map['kidTolerance'] as num).toDouble(),
      sizeTolerance: (map['sizeTolerance'] as num).toDouble(),
      playStyles: List<String>.from(map['playStyles'] ?? []),
      triggers: List<String>.from(map['triggers'] ?? []),
      bio: map['bio'] as String?,
      isSpayedNeutered: map['isSpayedNeutered'] as bool? ?? false,
      isVaccinated: map['isVaccinated'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      meetupCount: map['meetupCount'] as int? ?? 0,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      ownerApproxLat: (map['ownerApproxLat'] as num?)?.toDouble(),
      ownerApproxLng: (map['ownerApproxLng'] as num?)?.toDouble(),
      vetClinicName: map['vetClinicName'] as String?,
      vetClinicAddress: map['vetClinicAddress'] as String?,
      vetClinicLatitude: (map['vetClinicLatitude'] as num?)?.toDouble(),
      vetClinicLongitude: (map['vetClinicLongitude'] as num?)?.toDouble(),
      vetGooglePlaceId: map['vetGooglePlaceId'] as String?,
    );
  }

  Pet copyWith({
    String? name,
    String? type,
    String? breed,
    String? gender,
    String? size,
    int? ageYears,
    int? ageMonths,
    String? photoUrl,
    List<String>? photoGallery,
    List<String>? videoPaths,
    double? energyLevel,
    double? socialComfort,
    double? kidTolerance,
    double? sizeTolerance,
    List<String>? playStyles,
    List<String>? triggers,
    String? bio,
    bool? isSpayedNeutered,
    bool? isVaccinated,
    int? meetupCount,
    double? averageRating,
    double? ownerApproxLat,
    double? ownerApproxLng,
    String? vetClinicName,
    String? vetClinicAddress,
    double? vetClinicLatitude,
    double? vetClinicLongitude,
    String? vetGooglePlaceId,
    bool clearVetClinicLink = false,
  }) {
    if (clearVetClinicLink) {
      return Pet(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        type: type ?? this.type,
        breed: breed ?? this.breed,
        gender: gender ?? this.gender,
        size: size ?? this.size,
        ageYears: ageYears ?? this.ageYears,
        ageMonths: ageMonths ?? this.ageMonths,
        photoUrl: photoUrl ?? this.photoUrl,
        photoGallery: photoGallery ?? this.photoGallery,
        videoPaths: videoPaths ?? this.videoPaths,
        energyLevel: energyLevel ?? this.energyLevel,
        socialComfort: socialComfort ?? this.socialComfort,
        kidTolerance: kidTolerance ?? this.kidTolerance,
        sizeTolerance: sizeTolerance ?? this.sizeTolerance,
        playStyles: playStyles ?? this.playStyles,
        triggers: triggers ?? this.triggers,
        bio: bio ?? this.bio,
        isSpayedNeutered: isSpayedNeutered ?? this.isSpayedNeutered,
        isVaccinated: isVaccinated ?? this.isVaccinated,
        createdAt: createdAt,
        meetupCount: meetupCount ?? this.meetupCount,
        averageRating: averageRating ?? this.averageRating,
        ownerApproxLat: ownerApproxLat ?? this.ownerApproxLat,
        ownerApproxLng: ownerApproxLng ?? this.ownerApproxLng,
        vetClinicName: null,
        vetClinicAddress: null,
        vetClinicLatitude: null,
        vetClinicLongitude: null,
        vetGooglePlaceId: null,
      );
    }
    return Pet(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      size: size ?? this.size,
      ageYears: ageYears ?? this.ageYears,
      ageMonths: ageMonths ?? this.ageMonths,
      photoUrl: photoUrl ?? this.photoUrl,
      photoGallery: photoGallery ?? this.photoGallery,
      videoPaths: videoPaths ?? this.videoPaths,
      energyLevel: energyLevel ?? this.energyLevel,
      socialComfort: socialComfort ?? this.socialComfort,
      kidTolerance: kidTolerance ?? this.kidTolerance,
      sizeTolerance: sizeTolerance ?? this.sizeTolerance,
      playStyles: playStyles ?? this.playStyles,
      triggers: triggers ?? this.triggers,
      bio: bio ?? this.bio,
      isSpayedNeutered: isSpayedNeutered ?? this.isSpayedNeutered,
      isVaccinated: isVaccinated ?? this.isVaccinated,
      createdAt: createdAt,
      meetupCount: meetupCount ?? this.meetupCount,
      averageRating: averageRating ?? this.averageRating,
      ownerApproxLat: ownerApproxLat ?? this.ownerApproxLat,
      ownerApproxLng: ownerApproxLng ?? this.ownerApproxLng,
      vetClinicName: vetClinicName ?? this.vetClinicName,
      vetClinicAddress: vetClinicAddress ?? this.vetClinicAddress,
      vetClinicLatitude: vetClinicLatitude ?? this.vetClinicLatitude,
      vetClinicLongitude: vetClinicLongitude ?? this.vetClinicLongitude,
      vetGooglePlaceId: vetGooglePlaceId ?? this.vetGooglePlaceId,
    );
  }
}
