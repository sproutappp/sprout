import 'dart:io';
import 'dart:math';

import '../core/supabase/supabase_service.dart';
import '../models/memory.dart';

/// All memory reads/writes and photo uploads go through here.
///
/// The `memories` storage bucket is PRIVATE. The `image_url` column in
/// the DB actually stores the storage *path* (e.g. "memoryId/123.jpg"),
/// not a usable link — every fetch method here resolves paths to
/// short-lived signed URLs before handing Memory objects back to the UI.
///
/// A memory is either:
///  - public (`is_public = true`, visible to any signed-in user, shows
///    up in Discover), or
///  - shared to one or more circles via the `memory_circles` join table
///    (visible only to members of those circles).
class MemoriesRepository {
  MemoriesRepository._();

  static final _client = SupabaseService.client;
  static const _bucket = 'memories';

  static const _signedUrlExpirySeconds = 60 * 60 * 24 * 7;

  /// Memories shared to [circleId] — queried via memory_circles, not the
  /// legacy single circle_id column.
  static Future<List<Memory>> fetchForCircle(String circleId) async {
    final rows = await _client
        .from('memory_circles')
        .select(
          'memories(*, profiles(id, full_name, avatar_url))',
        )
        .eq('circle_id', circleId);

    final memoryMaps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row['memories'] as Map))
        .toList();
    memoryMaps.sort(
      (a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String),
    );

    return _toMemoriesWithSignedUrls(memoryMaps);
  }

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

  /// "My Memories" — memories visible to the current user that are not
  /// public. This deliberately starts with a plain base-table query instead
  /// of PostgREST relationship expansion. The previous `profiles(...),
  /// circles(...)` expansion could make the whole feed fail when a related
  /// row/relationship was not available under RLS, even though the memory
  /// itself was readable. The list screen only needs the memory fields, so
  /// related display data is enriched separately below.
  static Future<List<Memory>> fetchAllForUser() async {
    final rows = await _client
        .from('memories')
        .select(
          'id, circle_id, uploaded_by, image_url, caption, created_at, is_public',
        )
        .eq('is_public', false)
        .order('created_at', ascending: false);

    final memoryMaps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    if (memoryMaps.isEmpty) return [];

    // Circle names are presentation data. If a memory is visible through a
    // secondary circle but its primary circle isn't visible to the current
    // user, RLS may omit that circle row; the memory itself must still stay
    // in the feed, with the neutral "Circle" label used by the UI.
    final circleIds = memoryMaps
        .map((m) => m['circle_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (circleIds.isNotEmpty) {
      final circles = await _client
          .from('circles')
          .select('id, name')
          .inFilter('id', circleIds);
      final namesById = <String, String>{
        for (final row in (circles as List))
          (row['id'] as String): (row['name'] as String),
      };
      for (final memory in memoryMaps) {
        final circleId = memory['circle_id'] as String?;
        if (circleId != null && namesById.containsKey(circleId)) {
          memory['circles'] = {'id': circleId, 'name': namesById[circleId]};
        }
      }
    }

    return _toMemoriesWithSignedUrls(memoryMaps);
  }

  /// The public feed for Discover.
  static Future<List<Memory>> fetchPublicMemories() async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('is_public', true)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }

  static Future<List<Memory>> _toMemoriesWithSignedUrls(List rows) async {
    if (rows.isEmpty) return [];

    final maps = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    final paths = maps.map((m) => m['image_url'] as String).toList();

    List<dynamic> signed;
    try {
      signed = await _client.storage
          .from(_bucket)
          .createSignedUrls(paths, _signedUrlExpirySeconds);
    } catch (_) {
      return maps.map(Memory.fromMap).toList();
    }

    for (var i = 0; i < maps.length; i++) {
      final signedUrl = signed[i].signedUrl as String?;
      maps[i]['image_url'] = (signedUrl != null && signedUrl.isNotEmpty)
          ? signedUrl
          : maps[i]['image_url'];
    }

    return maps.map(Memory.fromMap).toList();
  }

  static Future<List<Memory>> fetchByUploader(String uploaderId) async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('uploaded_by', uploaderId)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }

  static final _rng = Random.secure();

  static String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  static Future<Memory> addMemory({
    required File file,
    String? caption,
    bool isPublic = false,
    List<String> circleIds = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in to add a memory');
    }
    if (!isPublic && circleIds.isEmpty) {
      throw ArgumentError('Choose Public or at least one circle to share with.');
    }

    final id = _generateUuidV4();
    final ext = file.path.split('.').last;
    final path = '$id/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.from('memories').insert({
      'id': id,
      'circle_id': isPublic ? null : circleIds.first,
      'uploaded_by': userId,
      'image_url': path,
      'caption': caption,
      'is_public': isPublic,
    });

    try {
      if (!isPublic) {
        await _client.from('memory_circles').insert([
          for (final circleId in circleIds)
            {'memory_id': id, 'circle_id': circleId},
        ]);
      }

      await _client.storage.from(_bucket).upload(path, file);
    } catch (e) {
      await _client.from('memories').delete().eq('id', id);
      rethrow;
    }

    final row = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url)')
        .eq('id', id)
        .single();

    final resolved = await _toMemoriesWithSignedUrls([row]);
    return resolved.first;
  }
}
