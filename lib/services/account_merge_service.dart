import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import 'auth_service.dart';

/// Server-side account merge coordinator.
///
/// The current session must be the phone-primary account. The user then
/// proves ownership of the Google account with native Google Sign-In.
/// The Edge Function verifies both identities, merges all Sprout data into
/// the Google account, removes the old Supabase auth user, and returns.
/// The client then signs in with the same Google credential so the active
/// session belongs to the canonical account.
class AccountMergeService {
  AccountMergeService._();

  static const _function = 'merge-phone-google-account';

  static Future<void> mergePhoneAccountIntoGoogle({
    required String expectedEmail,
  }) async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      throw StateError('Please sign in with your mobile number first.');
    }

    final tokens = await AuthService.getGoogleTokensForAccountMerge();

    try {
      final response = await SupabaseService.client.functions.invoke(
        _function,
        headers: {
          'Authorization': 'Bearer ' + session.accessToken,
        },
        body: {
          'expected_email': expectedEmail.trim().toLowerCase(),
          'google_id_token': tokens['idToken'],
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('Account merge returned an invalid response.');
      }

      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw StateError(error);
      }

      if (data['success'] != true) {
        throw StateError('Could not merge the two Sprout accounts.');
      }

      final googleIdToken = tokens['idToken'];
      final googleAccessToken = tokens['accessToken'];
      if (googleIdToken == null || googleAccessToken == null) {
        throw StateError('Google verification completed without a reusable credential.');
      }

      await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleIdToken,
        accessToken: googleAccessToken,
      );

      final current = SupabaseService.client.auth.currentUser;
      final targetUserId = data['target_user_id'];
      if (current == null || targetUserId is! String || current.id != targetUserId) {
        throw StateError('Accounts were merged, but the canonical session could not be restored.');
      }
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] is String) {
        throw StateError(details['error'] as String);
      }
      throw StateError(
        e.reasonPhrase ?? 'Could not merge the Sprout accounts.',
      );
    }
  }
}
