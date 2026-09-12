import 'dart:io';
import 'dart:math';

import '../core/supabase/supabase_service.dart';
import '../models/memory.dart';

class MemoriesRepository {
  MemoriesRepository._();
  static final _client = SupabaseService.client;
  static const _bucket = 'memories';
  static const _signedUrlExpirySeconds = 60 * 60 * 24 * 7;

  static Future<List<Memory>> fetchForCircle(String circleId) async {
    final rows = await _client.from('memory_circles').select('memories(*, profiles(id, full_name, avatar_url))').eq('circle_id', circleId);
    final memoryMaps = (rows as List).map((row) => Map<String, dynamic>.from(row['memories'] as Map)).toList();
    memoryMaps.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return _toMemoriesWithSignedUrls(memoryMaps);
  }

  static Future<Memory?> fetchById(String memoryId) async {
    final row = await _client.from('memories').select('*, profiles(id, full_name, avatar_url), circles(id, name)').eq('id', memoryId).maybeSingle();
    if (row == null) return null;
    final resolved = await _toMemoriesWithSignedUrls([row]);
    return resolved.isEmpty ? null : resolved.first;
  }

  static Future<List<Memory>> fetchAllForUser() async {
    final rows = await _client.from('memories').select('id, circle_id, uploaded_by, image_url, caption, location, created_at, is_public').eq('is_public', false).order('created_at', ascending: false);
    final memoryMaps = (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    if (memoryMaps.isEmpty) return [];
    final circleIds = memoryMaps.map((m) => m['circle_id'] as String?).whereType<String>().toSet().toList();
    if (circleIds.isNotEmpty) {
      final circles = await _client.from('circles').select('id, name').inFilter('id', circleIds);
      final namesById = <String, String>{for (final row in (circles as List)) (row['id'] as String): (row['name'] as String)};
      for (final memory in memoryMaps) {
        final circleId = memory['circle_id'] as String?;
        if (circleId != null && namesById.containsKey(circleId)) memory['circles'] = {'id': circleId, 'name': namesById[circleId]};
      }
    }
    return _toMemoriesWithSignedUrls(memoryMaps);
  }

  /// Public memories are queried from the base memories table first rather
  /// than using PostgREST relationship expansion. This keeps Discover
  /// independent of relationship/RLS behavior while still enriching each
  /// memory with the uploader's public profile data in a separate query.
  static Future<List<Memory>> fetchPublicMemories() async {
    final rows = await _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, caption, location, created_at, is_public')
        .eq('is_public', true)
        .order('created_at', ascending: false);

    final memoryMaps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (memoryMaps.isEmpty) return [];

    final uploaderIds = memoryMaps
        .map((m) => m['uploaded_by'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (uploaderIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', uploaderIds);
      final profilesById = <String, Map<String, dynamic>>{
        for (final row in (profiles as List))
          (row['id'] as String): Map<String, dynamic>.from(row as Map),
      };
      for (final memory in memoryMaps) {
        final uploaderId = memory['uploaded_by'] as String?;
        final profile = uploaderId == null ? null : profilesById[uploaderId];
        if (profile != null) memory['profiles'] = profile;
      }
    }

    return _toMemoriesWithSignedUrls(memoryMaps);
  }

  static Future<List<Memory>> _toMemoriesWithSignedUrls(List rows) async {
    if (rows.isEmpty) return [];
    final maps = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    final paths = maps.map((m) => m['image_url'] as String).toList();
    try {
      final signed = await _client.storage.from(_bucket).createSignedUrls(paths, _signedUrlExpirySeconds);
      for (var i = 0; i < maps.length; i++) {
        final signedUrl = signed[i].signedUrl as String?;
        if (signedUrl != null && signedUrl.isNotEmpty) maps[i]['image_url'] = signedUrl;
      }
    } catch (_) {}
    return maps.map(Memory.fromMap).toList();
  }

  static Future<List<Memory>> fetchByUploader(String uploaderId) async {
    final rows = await _client.from('memories').select('*, profiles(id, full_name, avatar_url), circles(id, name)').eq('uploaded_by', uploaderId).order('created_at', ascending: false);
    return _toMemoriesWithSignedUrls(rows as List);
  }

  static final _rng = Random.secure();
  static String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) => bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  static Future<Memory> addMemory({
    required File file,
    String? caption,
    String? location,
    bool isPublic = false,
    List<String> circleIds = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to add a memory');
    if (!isPublic && circleIds.isEmpty) throw ArgumentError('Choose Public or at least one circle to share with.');

    final id = _generateUuidV4();
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$id/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.from('memories').insert({
      'id': id,
      'circle_id': isPublic ? null : circleIds.first,
      'uploaded_by': userId,
      'image_url': path,
      'caption': caption,
      'location': location,
      'is_public': isPublic,
    });

    try {
      if (!isPublic) {
        await _client.from('memory_circles').insert([
          for (final circleId in circleIds) {'memory_id': id, 'circle_id': circleId},
        ]);
      }
      await _client.storage.from(_bucket).upload(path, file);
    } catch (e) {
      try { await _client.from('memories').delete().eq('id', id); } catch (_) {}
      rethrow;
    }

    final row = await _client.from('memories').select('id, circle_id, uploaded_by, image_url, caption, location, created_at, is_public').eq('id', id).single();
    final resolved = await _toMemoriesWithSignedUrls([row]);
    return resolved.first;
  }
}
