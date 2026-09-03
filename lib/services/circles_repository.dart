import '../core/supabase/supabase_service.dart';
import '../models/circle.dart';
import '../models/profile.dart';

/// All circle reads/writes go through here — screens never touch
/// the Supabase client directly. Swapping backends later means
/// rewriting this one file, not every screen.
class CirclesRepository {
  CirclesRepository._();

  static final _client = SupabaseService.client;

  /// Circles the current user is a member of, newest first.
  static Future<List<Circle>> fetchMyCircles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // circle_members -> circles join, plus a member count per circle.
    final rows = await _client
        .from('circle_members')
        .select('circles(*, circle_members(count))')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return (rows as List).map((row) {
      final circleMap = Map<String, dynamic>.from(row['circles'] as Map);
      final members = circleMap['circle_members'] as List?;
      circleMap['member_count'] = members?.isNotEmpty == true
          ? members!.first['count']
          : 0;
      return Circle.fromMap(circleMap);
    }).toList();
  }

  static Future<Circle> createCircle({
    required String name,
    String? description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in to create a circle');
    }

    final circleRow = await _client
        .from('circles')
        .insert({
          'name': name,
          'description': description,
          'created_by': userId,
        })
        .select()
        .single();

    // Creator automatically joins their own circle as admin.
    await _client.from('circle_members').insert({
      'circle_id': circleRow['id'],
      'user_id': userId,
      'role': 'admin',
    });

    circleRow['member_count'] = 1;
    return Circle.fromMap(circleRow);
  }

  /// A single circle plus its member list (each with profile info),
  /// for the circle detail screen.
  static Future<({Circle circle, List<Profile> members})> fetchCircleDetail(
    String circleId,
  ) async {
    final circleRow = await _client
        .from('circles')
        .select('*, circle_members(count)')
        .eq('id', circleId)
        .single();

    final memberCountList = circleRow['circle_members'] as List?;
    circleRow['member_count'] =
        memberCountList?.isNotEmpty == true ? memberCountList!.first['count'] : 0;

    final memberRows = await _client
        .from('circle_members')
        .select('profiles(id, full_name, avatar_url)')
        .eq('circle_id', circleId);

    final members = (memberRows as List)
        .map((row) => Profile.fromMap(
              Map<String, dynamic>.from(row['profiles'] as Map),
            ))
        .toList();

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
