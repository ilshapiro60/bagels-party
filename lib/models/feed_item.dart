enum FeedItemType { video, photo }

class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.mediaUrl,
    required this.authorName,
    this.authorPhotoUrl,
    this.petName,
    this.petBreed,
    this.caption,
    this.areaLabel,
    this.petId,
    this.postId,
  });

  final String id;
  final FeedItemType type;
  final String mediaUrl;
  final String authorName;
  final String? authorPhotoUrl;
  final String? petName;
  final String? petBreed;
  final String? caption;

  /// Non-null when content comes from another area — shown as "Popular in [areaLabel]".
  final String? areaLabel;

  final String? petId;
  final String? postId;

  bool get isVideo => type == FeedItemType.video;
  bool get isFromOtherArea => areaLabel != null;

  String get displayName {
    if (petName != null && petName!.isNotEmpty) {
      return petBreed != null && petBreed!.isNotEmpty
          ? '$petName · $petBreed'
          : petName!;
    }
    return authorName.isNotEmpty ? authorName : 'ZumiTok';
  }
}
