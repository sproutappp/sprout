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
}
