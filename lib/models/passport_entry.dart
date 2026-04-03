class PassportEntry {
  final String id;
  final String petId;
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

  const PassportEntry({
    required this.id,
    required this.petId,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'petId': petId,
      'meetupId': meetupId,
      'meetupTitle': meetupTitle,
      'meetupTheme': meetupTheme,
      'date': date.toIso8601String(),
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
    };
  }

  factory PassportEntry.fromMap(Map<String, dynamic> map) {
    return PassportEntry(
      id: map['id'] as String,
      petId: map['petId'] as String,
      meetupId: map['meetupId'] as String,
      meetupTitle: map['meetupTitle'] as String,
      meetupTheme: map['meetupTheme'] as String?,
      date: DateTime.parse(map['date'] as String),
      hostName: map['hostName'] as String,
      metPetNames: List<String>.from(map['metPetNames'] ?? []),
      rating: (map['rating'] as num?)?.toDouble(),
      behaviorNotes: map['behaviorNotes'] as String?,
      playOutcome: PlayOutcome.values.byName(map['playOutcome'] as String),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      videoPaths: List<String>.from(map['videoPaths'] ?? []),
      wasAnxious: map['wasAnxious'] as bool? ?? false,
      playedWell: map['playedWell'] as bool? ?? true,
      warmUpMinutes: map['warmUpMinutes'] as int? ?? 0,
    );
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
