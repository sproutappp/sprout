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
    final rows = await _client.from('memory_circles').select('memories(*)').eq('circle_id', circleId);
    final memoryMaps = <Map<String, dynamic>>[];
    for (final row in (rows as List)) {
      if (row is! Map) continue;
      final rawMemory = row['memories'];
      if (rawMemory is Map) memoryMaps.add(Map<String, dynamic>.from(rawMemory));
    }
    memoryMaps.sort((a, b) {
      final aCreatedAt = a['created_at'];
      final bCreatedAt = b['created_at'];
      if (aCreatedAt is! String || bCreatedAt is! String) return 0;
      return bCreatedAt.compareTo(aCreatedAt);
    });
    return _toMemoriesWithSignedUrls(memoryMaps);
  }

  static Future<Memory?> fetchById(String memoryId) async {
    // Do not expand optional PostgREST relationships in the primary lookup.
    // A profile/circle relationship issue must not make an accessible memory
    // appear to have been deleted.
    final row = await _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, media_urls, caption, location, created_at, is_public')
        .eq('id', memoryId)
        .maybeSingle();
    if (row == null) return null;

    final resolved = Map<String, dynamic>.from(row);
    final uploaderId = resolved['uploaded_by'] as String?;
    if (uploaderId != null) {
      try {
        final profile = await _client.from('profiles').select('id, full_name, avatar_url').eq('id', uploaderId).maybeSingle();
        if (profile != null) resolved['profiles'] = profile;
      } catch (_) {}
    }

    final circleId = resolved['circle_id'] as String?;
    if (circleId != null) {
      try {
        final circle = await _client.from('circles').select('id, name').eq('id', circleId).maybeSingle();
        if (circle != null) resolved['circles'] = circle;
      } catch (_) {}
    }

    final converted = await _toMemoriesWithSignedUrls([resolved]);
    return converted.isEmpty ? null : converted.first;
  }

  static Future<List<Memory>> fetchAllForUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to load memories');
    final rows = await _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, media_urls, caption, location, created_at, is_public')
        .eq('uploaded_by', userId)
        .order('created_at', ascending: false);
    final memoryMaps = (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    if (memoryMaps.isEmpty) return [];

    final circleIds = memoryMaps.where((m) => m['is_public'] != true).map((m) => m['circle_id'] as String?).whereType<String>().toSet().toList();
    if (circleIds.isNotEmpty) {
      final circles = await _client.from('circles').select('id, name').inFilter('id', circleIds);
      final namesById = <String, String>{for (final row in (circles as List)) (row['id'] as String): (row['name'] as String)};
      for (final memory in memoryMaps) {
        final circleId = memory['circle_id'] as String?;
        if (memory['is_public'] != true && circleId != null && namesById.containsKey(circleId)) {
          memory['circles'] = {'id': circleId, 'name': namesById[circleId]};
        }
      }
    }
    return _toMemoriesWithSignedUrls(memoryMaps);
  }

  static Future<List<Memory>> fetchPublicMemories() async {
    final rows = await _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, media_urls, caption, location, created_at, is_public')
        .eq('is_public', true)
        .order('created_at', ascending: false);
    final memoryMaps = (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    if (memoryMaps.isEmpty) return [];

    final uploaderIds = memoryMaps.map((m) => m['uploaded_by'] as String?).whereType<String>().toSet().toList();
    if (uploaderIds.isNotEmpty) {
      final profiles = await _client.from('profiles').select('id, full_name, avatar_url').inFilter('id', uploaderIds);
      final profilesById = <String, Map<String, dynamic>>{
        for (final row in (profiles as List)) (row['id'] as String): Map<String, dynamic>.from(row as Map),
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
    final allPaths = <String>[];
    for (final map in maps) {
      final primary = map['image_url'] as String?;
      if (primary != null && primary.isNotEmpty) allPaths.add(primary);
      final rawMedia = map['media_urls'];
      if (rawMedia is List) allPaths.addAll(rawMedia.whereType<String>().where((p) => p.isNotEmpty));
    }

    if (allPaths.isNotEmpty) {
      try {
        final uniquePaths = allPaths.toSet().toList();
        final signed = await _client.storage.from(_bucket).createSignedUrls(uniquePaths, _signedUrlExpirySeconds);
        final signedByPath = <String, String>{};
        for (var i = 0; i < uniquePaths.length && i < signed.length; i++) {
          final signedUrl = signed[i].signedUrl as String?;
          if (signedUrl != null && signedUrl.isNotEmpty) signedByPath[uniquePaths[i]] = signedUrl;
        }
        for (final map in maps) {
          final primary = map['image_url'] as String?;
          if (primary != null && signedByPath.containsKey(primary)) map['image_url'] = signedByPath[primary];
          final rawMedia = map['media_urls'];
          if (rawMedia is List) {
            map['media_urls'] = rawMedia.whereType<String>().map((p) => signedByPath[p] ?? p).toList();
          }
        }
      } catch (_) {}
    }
    return maps.map(Memory.fromMap).toList();
  }

  static Future<List<Memory>> fetchByUploader(String uploaderId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId != null && currentUserId == uploaderId) return fetchAllForUser();
    final rows = await _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, media_urls, caption, location, created_at, is_public')
        .eq('uploaded_by', uploaderId)
        .order('created_at', ascending: false);
    return _toMemoriesWithSignedUrls(rows as List);
  }

  static Future<void> deleteMemory(String memoryId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to delete a memory');
    final row = await _client
        .from('memories')
        .select('id, image_url, media_urls, uploaded_by')
        .eq('id', memoryId)
        .eq('uploaded_by', userId)
        .maybeSingle();
    if (row == null) throw StateError('Memory not found or you do not own it');

    final paths = <String>[];
    final imagePath = row['image_url'] as String?;
    if (imagePath != null && imagePath.isNotEmpty) paths.add(imagePath);
    final rawMedia = row['media_urls'];
    if (rawMedia is List) paths.addAll(rawMedia.whereType<String>().where((p) => p.isNotEmpty));
    if (paths.isNotEmpty) {
      try { await _client.storage.from(_bucket).remove(paths.toSet().toList()); } catch (_) {}
    }
    await _client.from('memories').delete().eq('id', memoryId).eq('uploaded_by', userId);
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
      'media_urls': [path],
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

    final row = await _client
        .from('memories')
        .select('id, circle_id, uploaded_by, image_url, media_urls, caption, location, created_at, is_public')
        .eq('id', id)
        .single();
    final resolved = await _toMemoriesWithSignedUrls([row]);
    return resolved.first;
  }
}
