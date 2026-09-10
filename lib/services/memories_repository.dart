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
/// See supabase/schema.sql's migration block for the RLS that enforces
/// this — `can_view_memory()` is the single source of truth used by both
/// the `memories` table policy and the storage policy below.
class MemoriesRepository {
  MemoriesRepository._();

  static final _client = SupabaseService.client;
  static const _bucket = 'memories';

  // 7 days — long enough that the same signed URL stays stable across
  // app opens within that window (so CachedNetworkImage's URL-keyed
  // cache actually helps), short enough to rotate regularly.
  static const _signedUrlExpirySeconds = 60 * 60 * 24 * 7;

  /// Memories shared to [circleId] — queried via memory_circles, not the
  /// legacy single circle_id column, so this correctly includes memories
  /// shared to *several* circles including this one (not just ones where
  /// this was the first/primary circle selected).
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

  /// "My Memories" — every memory across every circle the current user
  /// belongs to. Deliberately excludes public memories: RLS now also
  /// makes every public memory (from anyone) visible to any signed-in
  /// user, but that belongs in Discover, not in a "your circles" feed —
  /// hence the explicit `is_public = false` filter, rather than relying
  /// on RLS visibility alone.
  static Future<List<Memory>> fetchAllForUser() async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('is_public', false)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }

  /// The public feed for Discover — every memory anyone has marked
  /// Public. RLS allows this for any signed-in user regardless of circle
  /// membership; the `is_public = true` filter here just makes the
  /// intent explicit rather than relying on RLS alone.
  static Future<List<Memory>> fetchPublicMemories() async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('is_public', true)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }

  /// Converts raw rows (image_url = storage path) into Memory objects
  /// with a real, usable signed URL swapped in.
  static Future<List<Memory>> _toMemoriesWithSignedUrls(List rows) async {
    if (rows.isEmpty) return [];

    final maps = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    final paths = maps.map((m) => m['image_url'] as String).toList();

    List<dynamic> signed;
    try {
      signed = await _client.storage
          .from(_bucket)
          .createSignedUrls(paths, _signedUrlExpirySeconds);
    } catch (e) {
      // One bad/inaccessible path shouldn't take down the whole list —
      // fall back to the raw (unusable) path for every item rather than
      // throwing and losing the entire fetch.
      return maps.map(Memory.fromMap).toList();
    }

    for (var i = 0; i < maps.length; i++) {
      // Fall back to the raw path (will just fail to load) rather than
      // throwing, so one bad/missing file doesn't break the whole list.
      final signedUrl = signed[i].signedUrl as String?;
      maps[i]['image_url'] = (signedUrl != null && signedUrl.isNotEmpty)
          ? signedUrl
          : maps[i]['image_url'];
    }

    return maps.map(Memory.fromMap).toList();
  }

  /// Memories uploaded by [uploaderId] that the *current* user can see.
  /// RLS on memories restricts every SELECT to circles the current
  /// session user belongs to, or memories marked public — so this
  /// naturally returns whatever the current user is actually allowed to
  /// see of that person's uploads, never anything outside it.
  static Future<List<Memory>> fetchByUploader(String uploaderId) async {
    final rows = await _client
        .from('memories')
        .select('*, profiles(id, full_name, avatar_url), circles(id, name)')
        .eq('uploaded_by', uploaderId)
        .order('created_at', ascending: false);

    return _toMemoriesWithSignedUrls(rows as List);
  }

  static final _rng = Random.secure();

  /// A client-generated UUID v4. Needed so the storage upload path can be
  /// known *before* the memories row is inserted (we insert the DB row
  /// first, using this id, then upload to `{id}/{filename}` — the storage
  /// insert policy checks that a memories row with this id and the
  /// current user as uploader already exists). Hand-rolled rather than
  /// pulling in the `uuid` package for one call site.
  static String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Creates a memory, either public or shared to one-or-more circles.
  ///
  /// Exactly one of [isPublic] or [circleIds] applies:
  ///  - `isPublic: true` → visible to everyone, shows up in Discover.
  ///  - `circleIds: [...]` (non-empty) → shared to every listed circle;
  ///    a member of *any* of them can see it. The first id is also kept
  ///    as the row's `circle_id` ("primary" circle) purely so existing
  ///    single-badge UI elsewhere keeps working.
  ///
  /// Upload order matters: the memories row is inserted FIRST (with a
  /// client-generated id), then the file is uploaded to `{id}/...` —
  /// the storage insert policy needs that row to already exist to check
  /// the uploader matches. If the upload fails, the just-inserted row is
  /// deleted so a failed save doesn't leave an orphaned, photo-less
  /// memory behind.
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
      // Roll back the row so a failed share/upload doesn't leave a
      // dangling memory with no accessible photo behind.
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
