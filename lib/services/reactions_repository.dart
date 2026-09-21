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

    // Use the same per-memory query as the detail screen. The previous
    // batched query could silently produce zero on the home/tray path even
    // though fetchSummary() could see the reaction for the same memory.
    // Keeping this path aligned with fetchSummary() ensures the count shown
    // on a memory detail is the count shown on its thumbnail as well.
    final counts = <String, int>{};
    final summaries = await Future.wait(
      memoryIds.map((memoryId) async {
        try {
          return MapEntry(memoryId, await fetchSummary(memoryId));
        } catch (_) {
          return MapEntry(memoryId, ReactionSummary.empty);
        }
      }),
    );

    for (final entry in summaries) {
      final summary = entry.value;
      // The like reaction is the heart. Accept both common Unicode forms so
      // older rows saved without the variation selector are counted too.
      var heartCount = 0;
      for (final reaction in summary.counts.entries) {
        final normalized = reaction.key.replaceAll('\uFE0F', '');
        if (normalized == '❤') heartCount += reaction.value;
      }
      if (heartCount > 0) counts[entry.key] = heartCount;
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
