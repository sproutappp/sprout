import 'profile.dart';

export '../presentation/memories_screen/widgets/memories_grid_widget.dart' show MemoryItem;

class Memory {
  final String id;
  final String? circleId;
  final String uploadedBy;
  final String imageUrl;
  final String? discoverImageUrl;
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
    this.discoverImageUrl,
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
    final storedCaption = (map['caption'] as String?)?.trim();
    final separator = storedCaption?.indexOf(' — ') ?? -1;

    // Older memories stored title + caption in one caption field. Keep a
    // compatibility fallback so those rows display correctly even before
    // the database migration has been applied.
    final hasStoredTitle = storedTitle?.isNotEmpty == true;
    final title = hasStoredTitle
        ? storedTitle!
        : (separator > 0
            ? storedCaption!.substring(0, separator).trim()
            : (storedCaption?.isNotEmpty == true ? storedCaption! : 'A memory'));
    final caption = hasStoredTitle
        ? storedCaption
        : (separator > 0
            ? storedCaption!.substring(separator + 3).trim()
            : null);

    return Memory(
      id: map['id'] as String,
      circleId: map['circle_id'] as String?,
      uploadedBy: map['uploaded_by'] as String,
      imageUrl: imageUrl,
      discoverImageUrl: map['discover_image_url'] as String?,
      mediaUrls: mediaUrls.isEmpty ? [imageUrl] : mediaUrls,
      title: title,
      caption: caption?.isEmpty == true ? null : caption,
      location: map['location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      contributor: contributorMap != null ? Profile.fromMap(contributorMap) : null,
      circleName: circleMap != null ? circleMap['name'] as String? : null,
      isPublic: map['is_public'] as bool? ?? false,
    );
  }
}
