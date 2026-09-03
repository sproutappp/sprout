import '../core/supabase/supabase_service.dart';
import '../models/comment.dart';

class CommentsRepository {
  CommentsRepository._();

  static final _client = SupabaseService.client;

  static Future<List<MemoryComment>> fetchForMemory(String memoryId) async {
    final rows = await _client
        .from('memory_comments')
        .select('*, profiles(id, full_name, avatar_url)')
        .eq('memory_id', memoryId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => MemoryComment.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<MemoryComment> addComment({
    required String memoryId,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to comment');

    final row = await _client
        .from('memory_comments')
        .insert({'memory_id': memoryId, 'user_id': userId, 'body': body})
        .select('*, profiles(id, full_name, avatar_url)')
        .single();

    return MemoryComment.fromMap(row);
  }
}
