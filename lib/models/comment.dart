import 'profile.dart';

class MemoryComment {
  final String id;
  final String memoryId;
  final String body;
  final DateTime createdAt;
  final Profile? author;

  const MemoryComment({
    required this.id,
    required this.memoryId,
    required this.body,
    required this.createdAt,
    this.author,
  });

  factory MemoryComment.fromMap(Map<String, dynamic> map) {
    final authorMap = map['profiles'] as Map<String, dynamic>?;
    return MemoryComment(
      id: map['id'] as String,
      memoryId: map['memory_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      author: authorMap != null ? Profile.fromMap(authorMap) : null,
    );
  }
}
