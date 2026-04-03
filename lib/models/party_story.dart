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
  });

  bool get hasMedia => imagePaths.isNotEmpty || videoPaths.isNotEmpty;
}
