import 'dart:io';

import '../core/supabase/supabase_service.dart';
import '../models/circle.dart';
import '../models/profile.dart';

/// All circle reads/writes go through here — screens never touch
/// the Supabase client directly. Swapping backends later means
/// rewriting this one file, not every screen.
class CirclesRepository {
  CirclesRepository._();

  static final _client = SupabaseService.client;
  static const _circleCoverBucket = 'circle-covers';

  /// Circles the current user is a member of, newest first.
  ///
  /// NOTE: this deliberately does NOT use PostgREST's embedded
  /// `circle_members(count)` aggregate. Postgres aggregate functions in
  /// embedded selects are disabled by default on Supabase projects (opt-in
  /// per project, added in PostgREST v12) — using it here caused the
  /// query to fail outright (not just return an empty count), which is
  /// what broke Profile/Discover even for a brand-new user with zero
  /// circles. Member counts are tallied client-side instead, from plain
  /// rows, so this works regardless of that project setting.
  static Future<List<Circle>> fetchMyCircles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final membershipRows = await _client
        .from('circle_members')
        .select('circles(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    final circleMaps = (membershipRows as List)
        .map((row) => Map<String, dynamic>.from(row['circles'] as Map))
        .toList();

    if (circleMaps.isEmpty) return [];

    final circleIds = circleMaps.map((c) => c['id'] as String).toList();
    final counts = await _memberCountsByCircle(circleIds);

    for (final c in circleMaps) {
      c['member_count'] = counts[c['id']] ?? 0;
    }

    return circleMaps.map(Circle.fromMap).toList();
  }

  /// Tallies member counts for the given circle ids from plain
  /// `circle_members` rows (no aggregate function required — see the
  /// note on [fetchMyCircles]).
  static Future<Map<String, int>> _memberCountsByCircle(
    List<String> circleIds,
  ) async {
    if (circleIds.isEmpty) return {};

    final rows = await _client
        .from('circle_members')
        .select('circle_id')
        .inFilter('circle_id', circleIds);

    final counts = <String, int>{};
    for (final row in (rows as List)) {
      final cid = row['circle_id'] as String;
      counts[cid] = (counts[cid] ?? 0) + 1;
    }
    return counts;
  }

  static Future<Circle> createCircle({
    required String name,
    String? description,
    required File coverFile,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in to create a circle');
    }

    final ext = coverFile.path.split('.').last.toLowerCase();
    final coverPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';

    // Upload first so the circle is never intentionally created without the
    // required cover image. Circle covers are presentation assets, so the
    // dedicated bucket is public (unlike private memory photos).
    await _client.storage
        .from(_circleCoverBucket)
        .upload(coverPath, coverFile);

    final coverUrl = _client.storage
        .from(_circleCoverBucket)
        .getPublicUrl(coverPath);

    String? circleId;
    try {
      final circleRow = await _client
          .from('circles')
          .insert({
            'name': name,
            'description': description,
            'cover_image_url': coverUrl,
            'created_by': userId,
          })
          .select()
          .single();

      circleId = circleRow['id'] as String;

      // Creator automatically joins their own circle as admin.
      await _client.from('circle_members').insert({
        'circle_id': circleId,
        'user_id': userId,
        'role': 'admin',
      });

      circleRow['member_count'] = 1;
      return Circle.fromMap(circleRow);
    } catch (e) {
      // Best-effort rollback: don't leave an orphaned cover (or circle) if
      // the database portion of creation fails.
      if (circleId != null) {
        try {
          await _client.from('circles').delete().eq('id', circleId);
        } catch (_) {}
      }
      try {
        await _client.storage.from(_circleCoverBucket).remove([coverPath]);
      } catch (_) {}
      rethrow;
    }
  }

  /// A single circle plus its member list (each with profile info),
  /// for the circle detail screen.
  static Future<({Circle circle, List<Profile> members})> fetchCircleDetail(
    String circleId,
  ) async {
    // No `circle_members(count)` aggregate here either — see the note on
    // fetchMyCircles. We already fetch the full member list below, so the
    // count is just its length; no second query needed.
    final circleRow = await _client
        .from('circles')
        .select()
        .eq('id', circleId)
        .single();

    final memberRows = await _client
        .from('circle_members')
        .select('profiles(id, full_name, avatar_url)')
        .eq('circle_id', circleId);

    final members = (memberRows as List)
        .map((row) => Profile.fromMap(
              Map<String, dynamic>.from(row['profiles'] as Map),
            ))
        .toList();

    circleRow['member_count'] = members.length;

    return (circle: Circle.fromMap(circleRow), members: members);
  }

  /// Circles shared between the current user and [otherUserId]. RLS on
  /// circle_members already restricts every SELECT to circles the *current*
  /// session user belongs to — so filtering by otherUserId's rows here
  /// naturally returns only the overlap, never a circle the current user
  /// isn't actually in. No manual privacy filtering needed beyond that.
  static Future<List<Circle>> fetchSharedCircles(String otherUserId) async {
    final rows = await _client
        .from('circle_members')
        .select('circles(*)')
        .eq('user_id', otherUserId);

    return (rows as List)
        .map((row) => Circle.fromMap(
              Map<String, dynamic>.from(row['circles'] as Map),
            ))
        .toList();
  }

  /// Creates a real, redeemable invite token for a circle. The resulting
  /// link (sprout.app/join/<token>) is what actually lets someone join —
  /// the circle's raw id alone is never enough (RLS blocks self-join by
  /// design; only redeem_circle_invite is allowed to add someone).
  static Future<String> createInvite(String circleId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in to create an invite');
    }
    final row = await _client
        .from('circle_invites')
        .insert({'circle_id': circleId, 'created_by': userId})
        .select('token')
        .single();
    return row['token'] as String;
  }

  /// Redeems an invite token, adding the current user to that circle.
  /// Returns the circle's id on success. Throws with a user-facing
  /// message (from the RPC's `raise exception`) if the token is invalid,
  /// revoked, or expired.
  static Future<String> joinViaInvite(String token) async {
    final circleId = await _client.rpc(
      'redeem_circle_invite',
      params: {'invite_token': token},
    );
    return circleId as String;
  }

  /// Invite an existing user (by their profile id) into a circle.
  /// The inviter must already be a member (enforced by RLS).
  static Future<void> addMember({
    required String circleId,
    required String userId,
  }) async {
    await _client.from('circle_members').insert({
      'circle_id': circleId,
      'user_id': userId,
      'role': 'member',
    });
  }
}
