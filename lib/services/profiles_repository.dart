import '../core/supabase/supabase_service.dart';
import '../models/profile.dart';

class ProfilesRepository {
  ProfilesRepository._();

  static final _client = SupabaseService.client;

  static Future<Profile?> fetchCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromMap(row);
  }

  /// Any signed-in user's basic profile (name/avatar) — allowed by the
  /// "profiles are readable by any signed-in user" policy. Their circles
  /// and memories below are still only ever visible where RLS already
  /// allows it — this call alone doesn't expose anything private.
  static Future<Profile?> fetchById(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromMap(row);
  }
}
