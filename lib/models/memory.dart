import 'profile.dart';

class Memory {
  final String id;
  final String? circleId;
  final String uploadedBy;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final Profile? contributor;
  final String? circleName;
  final bool isPublic;

  const Memory({
    required this.id,
    this.circleId,
    required this.uploadedBy,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    this.contributor,
    this.circleName,
    this.isPublic = false,
  });

  factory Memory.fromMap(Map<String, dynamic> map) {
    final contributorMap = map['profiles'] as Map<String, dynamic>?;
    final circleMap = map['circles'] as Map<String, dynamic>?;
    return Memory(
      id: map['id'] as String,
      // Nullable now — a public memory has no single circle_id. Still
      // populated for circle-scoped memories as the "primary" (first
      // selected) circle, for the existing single-badge UI.
      circleId: map['circle_id'] as String?,
      uploadedBy: map['uploaded_by'] as String,
      imageUrl: map['image_url'] as String,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      contributor:
          contributorMap != null ? Profile.fromMap(contributorMap) : null,
      circleName: circleMap != null ? circleMap['name'] as String? : null,
      isPublic: map['is_public'] as bool? ?? false,
    );
  }
}
