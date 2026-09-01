import 'profile.dart';

class Memory {
  final String id;
  final String circleId;
  final String uploadedBy;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final Profile? contributor;
  final String? circleName;

  const Memory({
    required this.id,
    required this.circleId,
    required this.uploadedBy,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    this.contributor,
    this.circleName,
  });

  factory Memory.fromMap(Map<String, dynamic> map) {
    final contributorMap = map['profiles'] as Map<String, dynamic>?;
    final circleMap = map['circles'] as Map<String, dynamic>?;
    return Memory(
      id: map['id'] as String,
      circleId: map['circle_id'] as String,
      uploadedBy: map['uploaded_by'] as String,
      imageUrl: map['image_url'] as String,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      contributor:
          contributorMap != null ? Profile.fromMap(contributorMap) : null,
      circleName: circleMap != null ? circleMap['name'] as String? : null,
    );
  }
}
