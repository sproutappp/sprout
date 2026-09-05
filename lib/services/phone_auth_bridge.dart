import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'firebase_auth_service.dart';

/// Bridges a Firebase-verified phone number into a real Supabase identity.
///
/// Why this exists (don't "simplify" this away without re-reading):
/// Supabase's native Third-Party Auth mode would disable email/password
/// and Google sign-in entirely on this client — confirmed directly
/// against Supabase's own SupabaseClient docs: "When set, the auth
/// [methods] cannot be used." Our schema also requires every user to
/// have a row in Supabase's own auth.users table, which Third-Party
/// Auth users never get. So instead of that mechanism, once Firebase
/// verifies a phone number we create (or sign back into) a completely
/// ordinary Supabase account for it — same as any other Supabase user,
/// just keyed by a synthetic email with a random password the person
/// never sees or types.
///
/// That password is stashed in Firestore, in a document only that exact
/// Firebase UID can read — enforced by a Firestore security rule, not
/// just client-side trust (see firestore.rules in the repo root). That's
/// what lets a returning user get back into the *same* Supabase account
/// after re-verifying their phone on a new device.
class PhoneAuthBridge {
  PhoneAuthBridge._();

  static const _vaultCollection = 'phone_auth_vault';

  static String _syntheticEmailFor(String e164Phone) {
    final digits = e164Phone.replaceAll(RegExp(r'\D'), '');
    // .invalid is an IETF-reserved TLD (RFC 2606) guaranteed to never
    // resolve — the correct choice for an address that must never
    // actually be deliverable.
    return '$digits@phone.sprout.invalid';
  }

  static String _generateSecurePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Call this once Firebase has genuinely verified the phone number.
  /// Establishes a real Supabase session for it: creates one on first
  /// use for this phone number, or recovers the existing one on a
  /// later device. Throws with a user-facing message on failure.
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
      if (password == null) {
        throw StateError(
          "This phone number's saved sign-in couldn't be found. Please contact support.",
        );
      }
      await AuthService.signIn(email: email, password: password);
      return;
    }

    // First time this phone number has completed the bridge.
    final password = _generateSecurePassword();
    try {
      await AuthService.signUp(email: email, password: password, fullName: '');
    } on AuthException catch (e) {
      // The Supabase account already exists (e.g. a race between two
      // devices, or the Firestore write below failed on a previous
      // attempt) but we have no way to recover a password we never
      // stored. Surface this honestly rather than guessing.
      final alreadyExists = e.message.toLowerCase().contains('already registered');
      throw StateError(
        alreadyExists
            ? "This phone number is already set up, but its saved sign-in wasn't found on this device. Please contact support."
            : 'Could not finish setting up your account — try again.',
      );
    }

    // Only stash the password once Supabase genuinely has the account —
    // never write credentials for an account that might not exist.
    await vaultRef.set({
      'password': password,
      'phone': e164Phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
