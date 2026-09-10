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

  // ── Identity linking ───────────────────────────────────────────────
  //
  // Goal: the same person should have ONE Sprout profile regardless of
  // whether they authenticate with Google/email or phone OTP. The
  // existing PhoneAuthBridge creates a brand-new Supabase account keyed
  // by a synthetic email per phone number — reusing that flow here would
  // sign the CURRENTLY authenticated user out of their real account and
  // into that synthetic one instead of linking anything. So linking is
  // deliberately implemented as a separate, narrower path: verify via
  // Firebase, then attach the verified value directly to the profile
  // that's already signed in — no new Supabase account, no session
  // change, and PhoneAuthBridge itself is untouched.

  /// Whether [e164Phone] is already linked to *some* profile (any
  /// profile, not necessarily this one). Used to give a clear "already
  /// in use" message before even starting Firebase verification, without
  /// ever exposing whose account it belongs to (see
  /// is_mobile_number_taken in schema.sql — a security-definer function,
  /// not a direct table read).
  static Future<bool> isMobileNumberTaken(String e164Phone) async {
    final result = await _client.rpc(
      'is_mobile_number_taken',
      params: {'phone': e164Phone},
    );
    return result as bool;
  }

  /// The current user's own linked mobile number, if any. Lives in
  /// `private_profile_info` (owner-only RLS), not on `profiles` — see
  /// the migration notes in schema.sql for why.
  static Future<String?> fetchLinkedMobileNumber() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('private_profile_info')
        .select('mobile_number')
        .eq('id', userId)
        .maybeSingle();
    return row?['mobile_number'] as String?;
  }

  /// Links [e164Phone] to the CURRENTLY signed-in profile. Call this only
  /// after Firebase has already verified the OTP for this number (see
  /// FirebaseAuthService.verifyOtp) — this method itself does not
  /// re-verify, it only persists the result of a verification the caller
  /// already completed.
  ///
  /// Throws a [StateError] if the number is already linked to a
  /// *different* profile (enforced by the unique index in schema.sql —
  /// this is just a friendlier error than the raw Postgrest one).
  static Future<void> linkMobileNumber(String e164Phone) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Must be signed in to link a mobile number');

    try {
      await _client.from('private_profile_info').upsert({
        'id': userId,
        'mobile_number': e164Phone,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // unique_violation on private_profile_info_mobile_unique_idx
        throw StateError(
          'This mobile number is already linked to a different account.',
        );
      }
      rethrow;
    }
  }

  /// Links a new email to the current account using Supabase's own email
  /// change flow (not a new column/table) — this sends a confirmation
  /// link to the new address per the project's existing email-auth
  /// configuration, and only takes effect once confirmed. Used for a
  /// phone-primary account (email currently unset) adding an email.
  static Future<void> linkEmail(String email) async {
    await _client.auth.updateUser(UserAttributes(email: email));
  }
}
