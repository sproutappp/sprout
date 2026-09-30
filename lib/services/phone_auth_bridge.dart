import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';
import 'profiles_repository.dart';

/// Bridges a Firebase-verified phone number into a real Supabase identity.
///
/// Supabase native third-party Firebase auth is not used here because Sprout's
/// existing data model relies on real Supabase auth.users rows and the app
/// already supports native Supabase Google/email sessions. Phone users
/// therefore get an ordinary Supabase account with an internal synthetic
/// email and a random password that the user never sees.
///
/// The password is stored in a Firebase-UID-scoped Firestore document. If an
/// old/stale password no longer matches the Supabase account, the verified
/// Firebase ID token is sent to the server-side recover-phone-account Edge
/// Function. That function verifies the Firebase token and rotates the
/// Supabase password without exposing the Supabase service key to the app.
class PhoneAuthBridge {
  PhoneAuthBridge._();

  static const _vaultCollection = 'phone_auth_vault';
  static const _recoveryFunction = 'recover-phone-account';

  static String _syntheticEmailFor(String e164Phone) {
    final digits = e164Phone.replaceAll(RegExp(r'\D'), '');
    return 'phone+$digits@sproutapp.in';
  }

  static String _generateSecurePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static Future<String> _recoverSupabaseCredential(String e164Phone) async {
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
        throw StateError('Phone account recovery returned an invalid response.');
      }

      final password = data['password'];
      if (password is! String || password.isEmpty) {
        final message = data['error'];
        throw StateError(
          message is String && message.isNotEmpty
              ? message
              : 'Could not recover the phone account.',
        );
      }

      return password;
    } on FunctionException catch (e) {
      final context = e.details;
      if (context is Map && context['error'] is String) {
        throw StateError(context['error'] as String);
      }
      throw StateError('Could not recover the phone account: ${e.reasonPhrase}');
    }
  }

  /// Call this once Firebase has genuinely verified the phone number.
  ///
  /// First tries the existing Firebase-UID-scoped Supabase credential. If
  /// that credential is stale, securely rotates the Supabase password on the
  /// server and signs in with the new credential.
  static Future<void> completeSignIn(String e164Phone) async {
    final firebaseUser = FirebaseAuthService.currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'No verified Firebase user — call this only after verifyOtp succeeds.',
      );
    }

    final email = _syntheticEmailFor(e164Phone);
    final vaultRef = FirebaseFirestore.instance
        .collection(_vaultCollection)
        .doc(firebaseUser.uid);

    final existing = await vaultRef.get();

    if (existing.exists) {
      final password = existing.data()?['password'] as String?;
      if (password == null || password.isEmpty) {
        final recoveredPassword = await _recoverSupabaseCredential(e164Phone);
        await AuthService.signIn(
          email: email,
          password: recoveredPassword,
        );
        await vaultRef.set({
          'password': recoveredPassword,
          'phone': e164Phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      try {
        await AuthService.signIn(email: email, password: password);
        return;
      } on AuthException catch (e) {
        final message = e.message.toLowerCase();
        final credentialFailure =
            message.contains('invalid login credentials') ||
            message.contains('invalid credentials') ||
            message.contains('email not confirmed');

        if (!credentialFailure) {
          rethrow;
        }

        // The Firebase OTP is already verified. Recover the existing
        // Supabase identity server-side instead of creating a duplicate.
        final recoveredPassword =
            await _recoverSupabaseCredential(e164Phone);

        await AuthService.signIn(
          email: email,
          password: recoveredPassword,
        );

        await vaultRef.set({
          'password': recoveredPassword,
          'phone': e164Phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }
    }

    // First time this phone has completed the bridge.
    //
    // Best-effort duplicate guard: if this exact number is already linked to
    // a real Google/email account, do not silently create a second profile.
    try {
      final alreadyLinkedElsewhere =
          await ProfilesRepository.isMobileNumberTaken(e164Phone);
      if (alreadyLinkedElsewhere) {
        throw StateError(
          'This mobile number is already linked to an existing account. '
          'Please sign in with the original method (Google or email) and '
          "it'll already be there.",
        );
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // This check is intentionally fail-open so a temporary issue with the
      // duplicate guard does not block all new phone registrations.
    }

    final password = _generateSecurePassword();
    try {
      final response = await AuthService.signUp(
        email: email,
        password: password,
        fullName: '',
      );

      // If email confirmation is enabled, signUp may create the user but
      // return no session. Firebase has already verified the phone, so sign
      // in immediately with the same generated credential.
      if (response.session == null) {
        await AuthService.signIn(email: email, password: password);
      }
    } on AuthException catch (e) {
      final message = e.message.trim();
      final alreadyExists =
          message.toLowerCase().contains('already registered') ||
          message.toLowerCase().contains('user already registered');

      if (alreadyExists) {
        // A stale/missing Firestore vault can happen after reinstalling or
        // clearing local app data. Recover the existing Supabase identity
        // instead of creating a duplicate.
        final recoveredPassword =
            await _recoverSupabaseCredential(e164Phone);
        await AuthService.signIn(
          email: email,
          password: recoveredPassword,
        );
        await vaultRef.set({
          'password': recoveredPassword,
          'phone': e164Phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      throw StateError(
        'Could not finish setting up your account: $message',
      );
    }

    // Only stash the password once Supabase genuinely has the account.
    await vaultRef.set({
      'password': password,
      'phone': e164Phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
