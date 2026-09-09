import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/profile.dart';

class ProfilesRepository {
  ProfilesRepository._();

  static final _client = SupabaseService.client;
  static const _avatarBucket = 'avatars';

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

  /// Updates the current user's editable profile fields (currently full
  /// name and date of birth). Relies on the existing "users can update
  /// their own profile" RLS policy (auth.uid() = id) — no RLS change
  /// needed for this.
  ///
  /// NOTE: `date_of_birth` requires the migration added to
  /// supabase/schema.sql (`alter table profiles add column if not
  /// exists date_of_birth date;`) to have been run against the live
  /// project. Passing a non-null [dateOfBirth] before that migration
  /// runs will fail with a Postgrest "column does not exist" error.
  static Future<void> updateBasicInfo({
    required String fullName,
    DateTime? dateOfBirth,
    bool updateDateOfBirth = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to update profile');
    final updates = <String, dynamic>{'full_name': fullName};
    if (updateDateOfBirth) {
      // Stored as a plain date (no time/timezone) — matches the `date`
      // column type added in schema.sql.
      updates['date_of_birth'] = dateOfBirth == null
          ? null
          : '${dateOfBirth.year.toString().padLeft(4, '0')}-'
              '${dateOfBirth.month.toString().padLeft(2, '0')}-'
              '${dateOfBirth.day.toString().padLeft(2, '0')}';
    }
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  /// Uploads a new avatar and updates profiles.avatar_url to point at it.
  /// The `avatars` bucket is public — profile pictures are low-sensitivity
  /// compared to family memory photos, and every user's avatar_url is
  /// already readable by any signed-in user via the profiles table
  /// itself, so a public bucket doesn't expose anything RLS wasn't
  /// already going to show. This also avoids needing to refresh signed
  /// URLs for something this simple.
  static Future<String> uploadAvatar(File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to update profile');

    final ext = file.path.split('.').last;
    // Fixed filename per user (not timestamped) + upsert, so re-uploading
    // just replaces the old one instead of accumulating orphaned files.
    final path = '$userId/avatar.$ext';

    await _client.storage
        .from(_avatarBucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    final publicUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    // Cache-bust so CachedNetworkImage/the OS don't keep showing the old
    // photo under the same URL after a re-upload.
    final bustedUrl = '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('profiles')
        .update({'avatar_url': bustedUrl})
        .eq('id', userId);

    return bustedUrl;
  }

  static Future<void> removeAvatar() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to update profile');
    await _client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', userId);
  }
}
