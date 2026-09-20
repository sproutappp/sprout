import '../core/supabase/supabase_service.dart';

class ReactionSummary {
  final Map<String, int> counts;
  final String? myEmoji;
  const ReactionSummary({required this.counts, this.myEmoji});
  static const empty = ReactionSummary(counts: {});
  int get totalCount => counts.values.fold(0, (sum, count) => sum + count);
}

class ReactionsRepository {
  ReactionsRepository._();
  static final _client = SupabaseService.client;

  static Future<ReactionSummary> fetchSummary(String memoryId) async {
    final userId = _client.auth.currentUser?.id;
    final rows = await _client.from('memory_reactions').select('user_id, emoji').eq('memory_id', memoryId);
    final counts = <String, int>{};
    String? myEmoji;
    for (final row in rows as List) {
      final emoji = row['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (row['user_id'] == userId) myEmoji = emoji;
    }
    return ReactionSummary(counts: counts, myEmoji: myEmoji);
  }

  static Future<Map<String, int>> fetchLikeCounts(List<String> memoryIds) async {
    if (memoryIds.isEmpty) return {};
    final rows = await _client
        .from('memory_reactions')
        .select('memory_id, emoji')
        .inFilter('memory_id', memoryIds);
    final counts = <String, int>{};
    for (final row in rows as List) {
      if (row['emoji'] != '❤️') continue;
      final memoryId = row['memory_id'] as String?;
      if (memoryId == null) continue;
      counts[memoryId] = (counts[memoryId] ?? 0) + 1;
    }
    return counts;
  }

  static Future<void> setReaction(String memoryId, String emoji) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to react');
    await _client.from('memory_reactions').upsert({'memory_id': memoryId, 'user_id': userId, 'emoji': emoji});
  }

  static Future<void> removeReaction(String memoryId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('memory_reactions').delete().eq('memory_id', memoryId).eq('user_id', userId);
  }
}
