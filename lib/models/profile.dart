class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? createdAt;

  const Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : 'Member';
}
