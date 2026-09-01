class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  const Profile({required this.id, this.fullName, this.avatarUrl});

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : 'Member';
}
