import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/notification.dart';

class NotificationsRepository {
  NotificationsRepository._();

  static final _client = SupabaseService.client;

  /// Unread "new memory in your circle" count — the real number behind
  /// the "N new memories across your circles" banner on the Circles
  /// screen. Uses the header-based exact count (`count(CountOption.exact)`),
  /// not an embedded aggregate function — those are disabled by default
  /// on Supabase projects and would fail outright (see the note on
  /// CirclesRepository.fetchMyCircles for the same distinction).
  static Future<int> fetchUnreadCircleMemoryCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'circle_memory')
        .eq('is_read', false)
        .count(CountOption.exact);
    return response.count;
  }

  static Future<List<AppNotification>> fetchForUser() async {
    // Two separate FKs from notifications -> profiles (user_id, actor_id)
    // means we have to disambiguate which one PostgREST should embed —
    // hence the explicit constraint-name hint and the `actor` alias.
    final rows = await _client
        .from('notifications')
        .select(
          '*, actor:profiles!notifications_actor_id_fkey(id, full_name, avatar_url), circles(id, name)',
        )
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((row) => AppNotification.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> markAsRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  static Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
