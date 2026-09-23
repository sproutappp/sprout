import 'profile.dart';

// Memory list/detail compatibility item is defined by the existing memory
// grid widget. Re-exporting it here keeps existing model imports working
// without maintaining a second, conflicting MemoryItem declaration.
export '../presentation/memories_screen/widgets/memories_grid_widget.dart' show MemoryItem;

class Memory {
  final String id;
  final String? circleId;
  final String uploadedBy;
  final String imageUrl;
  final List<String> mediaUrls;
  final String title;
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
    this.title = 'A memory',
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
    final storedTitle = (map['title'] as String?)?.trim();
    final legacyCaption = (map['caption'] as String?)?.trim();
    final legacySeparator = legacyCaption?.indexOf(' — ') ?? -1;
    final title = storedTitle?.isNotEmpty == true
        ? storedTitle!
        : (legacySeparator > 0
            ? legacyCaption!.substring(0, legacySeparator).trim()
            : (legacyCaption?.isNotEmpty == true ? legacyCaption! : 'A memory'));
    return Memory(
      id: map['id'] as String,
      circleId: map['circle_id'] as String?,
      uploadedBy: map['uploaded_by'] as String,
      imageUrl: imageUrl,
      mediaUrls: mediaUrls.isEmpty ? [imageUrl] : mediaUrls,
      title: title,
      caption: legacyCaption,
      location: map['location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      contributor: contributorMap != null ? Profile.fromMap(contributorMap) : null,
      circleName: circleMap != null ? circleMap['name'] as String? : null,
      isPublic: map['is_public'] as bool? ?? false,
    );
  }
}
