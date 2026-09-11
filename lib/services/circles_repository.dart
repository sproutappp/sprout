import 'dart:io';

import '../core/supabase/supabase_service.dart';
import '../models/circle.dart';
import '../models/profile.dart';

class CirclesRepository {
  CirclesRepository._();
  static final _client = SupabaseService.client;
  static const _circleCoverBucket = 'circle-covers';

  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<List<Circle>> fetchMyCircles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final membershipRows = await _client.from('circle_members').select('circles(*)').eq('user_id', userId).order('joined_at', ascending: false);
    final circleMaps = (membershipRows as List).map((row) => Map<String, dynamic>.from(row['circles'] as Map)).toList();
    if (circleMaps.isEmpty) return [];
    final circleIds = circleMaps.map((c) => c['id'] as String).toList();
    final counts = await _memberCountsByCircle(circleIds);
    for (final c in circleMaps) c['member_count'] = counts[c['id']] ?? 0;
    return circleMaps.map(Circle.fromMap).toList();
  }

  static Future<Map<String, int>> _memberCountsByCircle(List<String> circleIds) async {
    if (circleIds.isEmpty) return {};
    final rows = await _client.from('circle_members').select('circle_id').inFilter('circle_id', circleIds);
    final counts = <String, int>{};
    for (final row in (rows as List)) {
      final cid = row['circle_id'] as String;
      counts[cid] = (counts[cid] ?? 0) + 1;
    }
    return counts;
  }

  static Future<List<String>> fetchMemberIds(String circleId) async {
    final rows = await _client.from('circle_members').select('user_id').eq('circle_id', circleId);
    return (rows as List).map((row) => row['user_id'] as String).toList();
  }

  static Future<List<Profile>> fetchMembersForCircles(List<String> circleIds) async {
    if (circleIds.isEmpty) return [];
    final rows = await _client.from('circle_members').select('user_id, profiles(id, full_name, avatar_url)').inFilter('circle_id', circleIds);
    final profilesById = <String, Profile>{};
    for (final row in (rows as List)) {
      final raw = row['profiles'];
      if (raw is Map) {
        final profile = Profile.fromMap(Map<String, dynamic>.from(raw));
        profilesById[profile.id] = profile;
      }
    }
    final profiles = profilesById.values.toList();
    profiles.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return profiles;
  }

  static Future<Circle> createCircle({required String name, String? description, File? coverFile}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to create a circle');
    if (coverFile == null) throw StateError('A circle cover image is required');
    final ext = coverFile.path.split('.').last.toLowerCase();
    final coverPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _client.storage.from(_circleCoverBucket).upload(coverPath, coverFile);
    final coverUrl = _client.storage.from(_circleCoverBucket).getPublicUrl(coverPath);
    String? circleId;
    try {
      final circleRow = await _client.from('circles').insert({'name': name, 'description': description, 'cover_image_url': coverUrl, 'created_by': userId}).select().single();
      circleId = circleRow['id'] as String;
      await _client.from('circle_members').insert({'circle_id': circleId, 'user_id': userId, 'role': 'admin'});
      circleRow['member_count'] = 1;
      return Circle.fromMap(circleRow);
    } catch (e) {
      if (circleId != null) { try { await _client.from('circles').delete().eq('id', circleId); } catch (_) {} }
      try { await _client.storage.from(_circleCoverBucket).remove([coverPath]); } catch (_) {}
      rethrow;
    }
  }

  static Future<Circle> updateCircle({required String circleId, required String name, String? description, File? coverFile}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to edit a circle');
    String? newCoverPath;
    String? newCoverUrl;
    if (coverFile != null) {
      final ext = coverFile.path.split('.').last.toLowerCase();
      newCoverPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await _client.storage.from(_circleCoverBucket).upload(newCoverPath, coverFile);
      newCoverUrl = _client.storage.from(_circleCoverBucket).getPublicUrl(newCoverPath);
    }
    try {
      final update = <String, dynamic>{'name': name, 'description': description};
      if (newCoverUrl != null) update['cover_image_url'] = newCoverUrl;
      final row = await _client.from('circles').update(update).eq('id', circleId).select().single();
      final memberCount = await _client.from('circle_members').select('user_id').eq('circle_id', circleId);
      row['member_count'] = (memberCount as List).length;
      return Circle.fromMap(row);
    } catch (e) {
      if (newCoverPath != null) { try { await _client.storage.from(_circleCoverBucket).remove([newCoverPath]); } catch (_) {} }
      rethrow;
    }
  }

  static Future<({Circle circle, List<Profile> members})> fetchCircleDetail(String circleId) async {
    final circleRow = await _client.from('circles').select().eq('id', circleId).single();
    final memberRows = await _client.from('circle_members').select('profiles(id, full_name, avatar_url)').eq('circle_id', circleId);
    final members = (memberRows as List).map((row) => Profile.fromMap(Map<String, dynamic>.from(row['profiles'] as Map))).toList();
    circleRow['member_count'] = members.length;
    return (circle: Circle.fromMap(circleRow), members: members);
  }

  static Future<List<Circle>> fetchSharedCircles(String otherUserId) async {
    final rows = await _client.from('circle_members').select('circles(*)').eq('user_id', otherUserId);
    return (rows as List).map((row) => Circle.fromMap(Map<String, dynamic>.from(row['circles'] as Map))).toList();
  }

  static Future<String> createInvite(String circleId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to create an invite');
    final row = await _client.from('circle_invites').insert({'circle_id': circleId, 'created_by': userId}).select('token').single();
    return row['token'] as String;
  }

  static Future<int> sendCircleInvites({required String circleId, required List<String> userIds}) async {
    final result = await _client.rpc('send_circle_invites', params: {
      'p_circle_id': circleId,
      'p_user_ids': userIds,
    });
    return (result as num).toInt();
  }

  static Future<String> joinViaInvite(String token) async {
    final circleId = await _client.rpc('redeem_circle_invite', params: {'invite_token': token});
    return circleId as String;
  }

  static Future<void> addMember({required String circleId, required String userId}) async {
    await _client.from('circle_members').insert({'circle_id': circleId, 'user_id': userId, 'role': 'member'});
  }
}
