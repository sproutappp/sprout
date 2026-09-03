import 'dart:io';

import '../core/supabase/supabase_service.dart';
import '../models/memory.dart';

/// All memory reads/writes and photo uploads go through here.
///
/// The `memories` storage bucket is PRIVATE. The `image_url` column in
/// the DB actually stores the storage *path* (e.g. "circleId/123_uid.jpg"),
/// not a usable link — every fetch method here resolves paths to
/// short-lived signed URLs before handing Memory objects back to the UI.
class MemoriesRepository {
  MemoriesRepository._();

  static final _client = SupabaseService.client;
  static const _bucket = 'memories';

  // 7 days — long enough that the same signed URL stays stable across
  // app opens within that window (so CachedNetworkImage's URL-keyed
  // cache actually helps), short enough to rotate regularly.
  static const _signedUrlExpirySeconds = 60 * 60 * 24 * 7;

  static Future<List<Memory>> fetchForCircle(String circleId) async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url)')
        .eq('circle_id', circleId)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }

  /// A single memory by id, with its signed URL resolved. Used when
  /// navigating to a memory from somewhere that only has its id (e.g.
  /// a notification) rather than the full object already in hand.
  static Future<Memory?> fetchById(String memoryId) async {
    final row = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('id', memoryId)
        .maybeSingle();

    if (row == null) return null;
    final resolved = await _toMemoriesWithSignedUrls([row]);
    return resolved.isEmpty ? null : resolved.first;
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

    return _toMemoriesWithSignedUrls(rows as List);
  }

  /// Converts raw rows (image_url = storage path) into Memory objects
  /// with a real, usable signed URL swapped in.
  static Future<List<Memory>> _toMemoriesWithSignedUrls(List rows) async {
    if (rows.isEmpty) return [];

    final maps = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    final paths = maps.map((m) => m['image_url'] as String).toList();

    final signed = await _client.storage
        .from(_bucket)
        .createSignedUrls(paths, _signedUrlExpirySeconds);

    for (var i = 0; i < maps.length; i++) {
      // Fall back to the raw path (will just fail to load) rather than
      // throwing, so one bad/missing file doesn't break the whole list.
      maps[i]['image_url'] = signed[i].signedUrl.isNotEmpty
          ? signed[i].signedUrl
          : maps[i]['image_url'];
    }

    return maps.map(Memory.fromMap).toList();
  }

  /// Memories uploaded by [uploaderId] that the *current* user can see.
  /// RLS on memories already restricts every SELECT to circles the current
  /// session user belongs to, so this naturally only returns memories that
  /// uploader added to a circle both users share — never anything outside it.
  static Future<List<Memory>> fetchByUploader(String uploaderId) async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('uploaded_by', uploaderId)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }
  /// Storage path is namespaced by circle so RLS policies can scope
  /// access per-circle (see supabase/schema.sql). The DB stores the raw
  /// path, not a URL — the bucket is private.
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

    final row = await _client
        .from('memories')
        .insert({
          'circle_id': circleId,
          'uploaded_by': userId,
          'image_url': path,
          'caption': caption,
        })
        .select('*, profiles(id, full_name, avatar_url)')
        .single();

    final resolved = await _toMemoriesWithSignedUrls([row]);
    return resolved.first;
  }
}
