import 'dart:io';

import '../core/supabase/supabase_service.dart';
import '../models/memory.dart';

/// All memory reads/writes and photo uploads go through here.
class MemoriesRepository {
  MemoriesRepository._();

  static final _client = SupabaseService.client;
  static const _bucket = 'memories';

  static Future<List<Memory>> fetchForCircle(String circleId) async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url)')
        .eq('circle_id', circleId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Memory.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Memories across every circle the current user belongs to (RLS scopes
  /// this automatically — no explicit circle_id filter needed). Also
  /// embeds the parent circle's name so the feed can show "Family",
  /// "College Friends", etc. next to each memory.
  static Future<List<Memory>> fetchAllForUser() async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Memory.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Uploads [file] to Supabase Storage, then writes the memory row.
  /// Storage path is namespaced by circle so RLS policies can scope
  /// access per-circle (see supabase/schema.sql).
  static Future<Memory> addMemory({
    required String circleId,
    required File file,
    String? caption,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in to add a memory');
    }

    final ext = file.path.split('.').last;
    final path =
        '$circleId/${DateTime.now().millisecondsSinceEpoch}_$userId.$ext';

    await _client.storage.from(_bucket).upload(path, file);
    final imageUrl = _client.storage.from(_bucket).getPublicUrl(path);

    final row = await _client
        .from('memories')
        .insert({
          'circle_id': circleId,
          'uploaded_by': userId,
          'image_url': imageUrl,
          'caption': caption,
        })
        .select()
        .single();

    return Memory.fromMap(row);
  }
}
