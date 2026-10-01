import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import 'firebase_auth_service.dart';

/// Completes a Firebase-verified phone login by asking the trusted
/// recover-phone-account Edge Function to create/recover the matching
/// Supabase user and return a real Supabase session.
///
/// This intentionally does not use the old Firestore password vault or
/// client-side signInWithPassword flow. Firebase has already verified the
/// phone, so the server is the single bridge between Firebase identity and
/// the existing Supabase auth.users/profile model.
class PhoneAuthBridge {
  PhoneAuthBridge._();

  static const _recoveryFunction = 'recover-phone-account';

  static Future<void> completeSignIn(String e164Phone) async {
    final firebaseUser = FirebaseAuthService.currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'No verified Firebase user — call this only after verifyOtp succeeds.',
      );
    }

    final firebaseIdToken = await firebaseUser.getIdToken(true);
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError(
        'Could not obtain the verified Firebase sign-in token. Please try again.',
      );
    }

    try {
      final response = await SupabaseService.client.functions.invoke(
        _recoveryFunction,
        headers: {
          'Authorization': 'Bearer $firebaseIdToken',
        },
        body: {
          'phone': e164Phone,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('Phone account setup returned an invalid response.');
      }

      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw StateError(error);
      }

      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];

      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty) {
        throw StateError(
          'Phone account setup did not return a valid Supabase session.',
        );
      }

      await SupabaseService.client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );

      if (SupabaseService.client.auth.currentSession == null) {
        throw StateError(
          'Phone account setup completed but no Supabase session was created.',
        );
      }
    } on FunctionException catch (e) {
      final context = e.details;
      if (context is Map && context['error'] is String) {
        throw StateError(context['error'] as String);
      }
      throw StateError(
        'Could not finish setting up your account: ${e.reasonPhrase}',
      );
    }
  }
}
