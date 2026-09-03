import '../core/supabase/supabase_service.dart';

/// Aggregated reaction state for one memory: how many of each emoji, and
/// which one (if any) the current user picked.
class ReactionSummary {
  final Map<String, int> counts; // emoji -> count
  final String? myEmoji;

  const ReactionSummary({required this.counts, this.myEmoji});

  static const empty = ReactionSummary(counts: {});
}

class ReactionsRepository {
  ReactionsRepository._();

  static final _client = SupabaseService.client;

  static Future<ReactionSummary> fetchSummary(String memoryId) async {
    final userId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('memory_reactions')
        .select('user_id, emoji')
        .eq('memory_id', memoryId);

    final counts = <String, int>{};
    String? myEmoji;
    for (final row in rows as List) {
      final emoji = row['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (row['user_id'] == userId) myEmoji = emoji;
    }
    return ReactionSummary(counts: counts, myEmoji: myEmoji);
  }

  /// Sets (or changes) the current user's reaction on a memory. One
  /// reaction per user per memory — this upserts on the (memory_id,
  /// user_id) primary key.
  static Future<void> setReaction(String memoryId, String emoji) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to react');
    await _client.from('memory_reactions').upsert({
      'memory_id': memoryId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  static Future<void> removeReaction(String memoryId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('memory_reactions')
        .delete()
        .eq('memory_id', memoryId)
        .eq('user_id', userId);
  }
}
