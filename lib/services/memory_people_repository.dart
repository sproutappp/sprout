import '../core/supabase/supabase_service.dart';
import '../models/profile.dart';

class MemoryPeopleRepository {
  MemoryPeopleRepository._();

  static final _client = SupabaseService.client;

  static Future<List<Profile>> fetchForMemory(String memoryId) async {
    final rows = await _client
        .from('memory_people')
        .select('person_id, profiles(id, full_name, avatar_url)')
        .eq('memory_id', memoryId);

    final result = <Profile>[];
    for (final row in rows as List) {
      final raw = row['profiles'];
      if (raw is Map) {
        result.add(Profile.fromMap(Map<String, dynamic>.from(raw)));
      }
    }
    result.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return result;
  }

  static Future<void> replaceForMemory({
    required String memoryId,
    required List<String> personIds,
  }) async {
    await _client.from('memory_people').delete().eq('memory_id', memoryId);
    if (personIds.isEmpty) return;
    await _client.from('memory_people').insert([
      for (final personId in personIds)
        {'memory_id': memoryId, 'person_id': personId},
    ]);
  }
}
