/// A shareable party moment: photos/videos + caption (PawParty Passport / feed).
class PartyStory {
  final String id;
  final String title;
  final String? caption;
  final DateTime createdAt;
  final String authorId;
  final String authorName;
  final String? authorPhotoPath;
  final String? meetupId;
  final List<String> imagePaths;
  final List<String> videoPaths;

  /// Author's approximate location at creation time (for community distance filter).
  final double? latitude;
  final double? longitude;
  final String? neighborhoodKey;

  const PartyStory({
    required this.id,
    required this.title,
    this.caption,
    required this.createdAt,
    required this.authorId,
    required this.authorName,
    this.authorPhotoPath,
    this.meetupId,
    this.imagePaths = const [],
    this.videoPaths = const [],
    this.latitude,
    this.longitude,
    this.neighborhoodKey,
  });

  bool get hasMedia => imagePaths.isNotEmpty || videoPaths.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoPath': authorPhotoPath,
      'meetupId': meetupId,
      'imagePaths': imagePaths,
      'videoPaths': videoPaths,
      'latitude': latitude,
      'longitude': longitude,
      'neighborhoodKey': neighborhoodKey,
    };
  }

  factory PartyStory.fromMap(Map<String, dynamic> map) {
    return PartyStory(
      id: map['id'] as String,
      title: map['title'] as String,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorPhotoPath: map['authorPhotoPath'] as String?,
      meetupId: map['meetupId'] as String?,
      imagePaths: List<String>.from(map['imagePaths'] ?? []),
      videoPaths: List<String>.from(map['videoPaths'] ?? []),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      neighborhoodKey: map['neighborhoodKey'] as String?,
    );
  }
}
