class Circle {
  final String id;
  final String name;
  final String? description;
  final String? coverImageUrl;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;

  const Circle({
    required this.id,
    required this.name,
    this.description,
    this.coverImageUrl,
    required this.createdBy,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory Circle.fromMap(Map<String, dynamic> map) {
    return Circle(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      // Populated when the query joins/aggregates circle_members.
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}
