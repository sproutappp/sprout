import '../core/supabase/supabase_service.dart';

class MemoryEditRepository {
  MemoryEditRepository._();

  static final _client = SupabaseService.client;

  static Future<Map<String, dynamic>?> fetchMemory(String memoryId) async {
    return _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, media_urls, title, caption, location, created_at, is_public')
        .eq('id', memoryId)
        .maybeSingle();
  }

  static Future<List<String>> fetchCircleIds(String memoryId) async {
    final rows = await _client.from('memory_circles').select('circle_id').eq('memory_id', memoryId);
    return (rows as List).map((row) => row['circle_id'] as String).toList();
  }

  static Future<void> updateMemory({
    required String memoryId,
    required String caption,
    String? location,
    required bool isPublic,
    required List<String> circleIds,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to edit a memory');
    if (!isPublic && circleIds.isEmpty) throw ArgumentError('Choose at least one circle for a private memory.');

    final stored = caption.trim();
    final separator = stored.indexOf(' — ');
    final title = separator > 0 ? stored.substring(0, separator).trim() : stored;
    final story = separator > 0 ? stored.substring(separator + 3).trim() : '';

    await _client.from('memories').update({
      'title': title.isEmpty ? null : title,
      'caption': story.isEmpty ? null : story,
      'location': location?.trim().isEmpty == true ? null : location?.trim(),
      'is_public': isPublic,
      'circle_id': isPublic ? null : circleIds.first,
    }).eq('id', memoryId).eq('uploaded_by', userId);

    await _client.from('memory_circles').delete().eq('memory_id', memoryId);
    if (!isPublic) {
      await _client.from('memory_circles').insert([
        for (final circleId in circleIds) {'memory_id': memoryId, 'circle_id': circleId},
      ]);
    }
  }

  static Future<void> addToCircle({
    required String memoryId,
    required String circleId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in');

    await _client.from('memory_circles').upsert({
      'memory_id': memoryId,
      'circle_id': circleId,
    }, onConflict: 'memory_id,circle_id');
  }
}
