import 'profile.dart';

enum AppNotificationType { circleMemory, circleJoin }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final Profile actor;
  final String? circleId;
  final String? circleName;
  final String? memoryId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actor,
    this.circleId,
    this.circleName,
    this.memoryId,
    required this.isRead,
    required this.createdAt,
  });

  static AppNotificationType _typeFromString(String v) {
    switch (v) {
      case 'circle_join':
        return AppNotificationType.circleJoin;
      case 'circle_memory':
      default:
        return AppNotificationType.circleMemory;
    }
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final actorMap = map['actor'] as Map<String, dynamic>?;
    final circleMap = map['circles'] as Map<String, dynamic>?;
    return AppNotification(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      actor: actorMap != null
          ? Profile.fromMap(actorMap)
          : const Profile(id: '', fullName: 'Someone'),
      circleId: map['circle_id'] as String?,
      circleName: circleMap != null ? circleMap['name'] as String? : null,
      memoryId: map['memory_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get message {
    switch (type) {
      case AppNotificationType.circleMemory:
        return '${actor.displayName} added a new memory to ${circleName ?? 'a circle'}';
      case AppNotificationType.circleJoin:
        return '${actor.displayName} joined ${circleName ?? 'your circle'}';
    }
  }
}
