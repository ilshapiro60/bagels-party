/// A single photo or video contributed to a shared party album.
///
/// Any host or accepted guest can add items to the album for a meetup.
/// Each contributor can only delete their own items.
class PartyAlbumItem {
  final String id;
  final String meetupId;
  final String uploaderId;
  final String uploaderName;
  final String mediaUrl;

  /// "photo" or "video"
  final String mediaType;
  final DateTime createdAt;

  const PartyAlbumItem({
    required this.id,
    required this.meetupId,
    required this.uploaderId,
    required this.uploaderName,
    required this.mediaUrl,
    this.mediaType = 'photo',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'meetupId': meetupId,
        'uploaderId': uploaderId,
        'uploaderName': uploaderName,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PartyAlbumItem.fromMap(Map<String, dynamic> map) {
    return PartyAlbumItem(
      id: map['id'] as String,
      meetupId: map['meetupId'] as String,
      uploaderId: map['uploaderId'] as String? ?? '',
      uploaderName: map['uploaderName'] as String? ?? '',
      mediaUrl: map['mediaUrl'] as String,
      mediaType: map['mediaType'] as String? ?? 'photo',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
