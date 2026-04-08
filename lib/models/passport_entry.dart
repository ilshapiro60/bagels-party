class PassportEntry {
  final String id;
  /// Firebase uid of the pet parent who owns this journal entry.
  final String ownerId;
  final String petId;
  /// Denormalized for community cards and search.
  final String petName;
  final String meetupId;
  final String meetupTitle;
  final String? meetupTheme;
  final DateTime date;
  final String hostName;
  final List<String> metPetNames;
  final double? rating;
  final String? behaviorNotes;
  final PlayOutcome playOutcome;
  final List<String> photoUrls;
  final List<String> videoPaths;
  final bool wasAnxious;
  final bool playedWell;
  final int warmUpMinutes;
  /// When true, any signed-in user can read this entry (Community tab).
  final bool isPublic;
  /// Lowercase concatenated fields for client-side search.
  final String searchText;

  const PassportEntry({
    required this.id,
    required this.ownerId,
    required this.petId,
    this.petName = '',
    required this.meetupId,
    required this.meetupTitle,
    this.meetupTheme,
    required this.date,
    required this.hostName,
    this.metPetNames = const [],
    this.rating,
    this.behaviorNotes,
    this.playOutcome = PlayOutcome.good,
    this.photoUrls = const [],
    this.videoPaths = const [],
    this.wasAnxious = false,
    this.playedWell = true,
    this.warmUpMinutes = 0,
    this.isPublic = false,
    this.searchText = '',
  });

  static String buildSearchText({
    required String meetupTitle,
    String? meetupTheme,
    String? behaviorNotes,
    required String hostName,
    required List<String> metPetNames,
    String petName = '',
  }) {
    final parts = <String>[
      meetupTitle,
      meetupTheme ?? '',
      behaviorNotes ?? '',
      hostName,
      petName,
      ...metPetNames,
    ];
    return parts.join(' ').toLowerCase();
  }

  PassportEntry copyWith({
    String? id,
    String? ownerId,
    String? petId,
    String? petName,
    String? meetupId,
    String? meetupTitle,
    String? meetupTheme,
    DateTime? date,
    String? hostName,
    List<String>? metPetNames,
    double? rating,
    String? behaviorNotes,
    PlayOutcome? playOutcome,
    List<String>? photoUrls,
    List<String>? videoPaths,
    bool? wasAnxious,
    bool? playedWell,
    int? warmUpMinutes,
    bool? isPublic,
    String? searchText,
  }) {
    return PassportEntry(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      meetupId: meetupId ?? this.meetupId,
      meetupTitle: meetupTitle ?? this.meetupTitle,
      meetupTheme: meetupTheme ?? this.meetupTheme,
      date: date ?? this.date,
      hostName: hostName ?? this.hostName,
      metPetNames: metPetNames ?? this.metPetNames,
      rating: rating ?? this.rating,
      behaviorNotes: behaviorNotes ?? this.behaviorNotes,
      playOutcome: playOutcome ?? this.playOutcome,
      photoUrls: photoUrls ?? this.photoUrls,
      videoPaths: videoPaths ?? this.videoPaths,
      wasAnxious: wasAnxious ?? this.wasAnxious,
      playedWell: playedWell ?? this.playedWell,
      warmUpMinutes: warmUpMinutes ?? this.warmUpMinutes,
      isPublic: isPublic ?? this.isPublic,
      searchText: searchText ?? this.searchText,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'petId': petId,
      'petName': petName,
      'meetupId': meetupId,
      'meetupTitle': meetupTitle,
      'meetupTheme': meetupTheme,
      'hostName': hostName,
      'metPetNames': metPetNames,
      'rating': rating,
      'behaviorNotes': behaviorNotes,
      'playOutcome': playOutcome.name,
      'photoUrls': photoUrls,
      'videoPaths': videoPaths,
      'wasAnxious': wasAnxious,
      'playedWell': playedWell,
      'warmUpMinutes': warmUpMinutes,
      'isPublic': isPublic,
      'searchText': searchText,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      ...toFirestoreMap(),
      'date': date.toIso8601String(),
    };
  }

  factory PassportEntry.fromMap(Map<String, dynamic> map) {
    return PassportEntry(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String? ?? '',
      petId: map['petId'] as String,
      petName: map['petName'] as String? ?? '',
      meetupId: map['meetupId'] as String,
      meetupTitle: map['meetupTitle'] as String,
      meetupTheme: map['meetupTheme'] as String?,
      date: _parseDate(map['date']),
      hostName: map['hostName'] as String,
      metPetNames: List<String>.from(map['metPetNames'] ?? []),
      rating: (map['rating'] as num?)?.toDouble(),
      behaviorNotes: map['behaviorNotes'] as String?,
      playOutcome: _parseOutcome(map['playOutcome']),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      videoPaths: List<String>.from(map['videoPaths'] ?? []),
      wasAnxious: map['wasAnxious'] as bool? ?? false,
      playedWell: map['playedWell'] as bool? ?? true,
      warmUpMinutes: map['warmUpMinutes'] as int? ?? 0,
      isPublic: map['isPublic'] as bool? ?? false,
      searchText: map['searchText'] as String? ?? '',
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v is String) return DateTime.parse(v);
  // Firestore Timestamp via dynamic map (handled in repository)
  return DateTime.now();
}

PlayOutcome _parseOutcome(dynamic v) {
  if (v is! String) return PlayOutcome.good;
  try {
    return PlayOutcome.values.byName(v);
  } catch (_) {
    return PlayOutcome.good;
  }
}

enum PlayOutcome {
  excellent,
  good,
  okay,
  difficult,
  notCompatible;

  String get label {
    switch (this) {
      case PlayOutcome.excellent:
        return 'Best Friends!';
      case PlayOutcome.good:
        return 'Played Well';
      case PlayOutcome.okay:
        return 'It Was Okay';
      case PlayOutcome.difficult:
        return 'A Bit Rough';
      case PlayOutcome.notCompatible:
        return 'Not a Match';
    }
  }

  String get emoji {
    switch (this) {
      case PlayOutcome.excellent:
        return '🌟';
      case PlayOutcome.good:
        return '😊';
      case PlayOutcome.okay:
        return '😐';
      case PlayOutcome.difficult:
        return '😟';
      case PlayOutcome.notCompatible:
        return '❌';
    }
  }
}
