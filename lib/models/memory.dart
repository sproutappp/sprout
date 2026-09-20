import 'profile.dart';

class Memory {
  final String id;
  final String? circleId;
  final String uploadedBy;
  final String imageUrl;
  final List<String> mediaUrls;
  final String? caption;
  final String? location;
  final DateTime createdAt;
  final Profile? contributor;
  final String? circleName;
  final bool isPublic;

  const Memory({
    required this.id,
    this.circleId,
    required this.uploadedBy,
    required this.imageUrl,
    this.mediaUrls = const [],
    this.caption,
    this.location,
    required this.createdAt,
    this.contributor,
    this.circleName,
    this.isPublic = false,
  });

  factory Memory.fromMap(Map<String, dynamic> map) {
    final contributorMap = map['profiles'] as Map<String, dynamic>?;
    final circleMap = map['circles'] as Map<String, dynamic>?;
    final rawMedia = map['media_urls'];
    final mediaUrls = rawMedia is List
        ? rawMedia.whereType<String>().where((url) => url.isNotEmpty).toList()
        : <String>[];
    final imageUrl = map['image_url'] as String;
    return Memory(
      id: map['id'] as String,
      circleId: map['circle_id'] as String?,
      uploadedBy: map['uploaded_by'] as String,
      imageUrl: imageUrl,
      mediaUrls: mediaUrls.isEmpty ? [imageUrl] : mediaUrls,
      caption: map['caption'] as String?,
      location: map['location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      contributor: contributorMap != null ? Profile.fromMap(contributorMap) : null,
      circleName: circleMap != null ? circleMap['name'] as String? : null,
      isPublic: map['is_public'] as bool? ?? false,
    );
  }
}
