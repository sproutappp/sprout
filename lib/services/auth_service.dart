import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/supabase/supabase_service.dart';

/// All auth calls go through here — screens never touch
/// `Supabase.instance.client.auth` directly.
class AuthService {
  static GoTrueClient get _auth => SupabaseService.client.auth;

  static Future<void>? _googleInitialization;

  static User? get currentUser => _auth.currentUser;

  static bool get isSignedIn => currentUser != null;

  /// Emits on every sign-in / sign-out / token-refresh event.
  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final user = response.user;
    if (user != null) {
      // Create the matching profiles row. Safe to call even if a
      // DB trigger already does this — `upsert` just overwrites.
      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
      });
    }

    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _auth.signOut();

  /// Google sign-in.
  ///
  /// Android uses Google's native Credential Manager flow instead of opening
  /// Chrome. This means there is no external browser tab left behind after
  /// the user returns to Sprout. Other platforms keep the existing Supabase
  /// OAuth flow for now.
  static Future<void> signInWithGoogle() async {
    Future<void> launchSupabaseGoogleOAuth() async {
      final launched = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'app.sprout.auth://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Could not start Google sign-in.');
      }
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      await launchSupabaseGoogleOAuth();
      return;
    }

    // Android first uses the native Credential Manager flow. If Google
    // returns the ambiguous "canceled" result after account selection
    // (which google_sign_in can use for configuration failures), or Supabase
    // rejects the native ID token, immediately fall back to the proven
    // Supabase OAuth flow instead of silently returning to the login screen.
    try {
      final googleSignIn = GoogleSignIn.instance;

      _googleInitialization ??= googleSignIn.initialize(
        serverClientId:
            '734501171389-8199tv2f24r3tt47clc462detk6avn00.apps.googleusercontent.com',
      );

      await _googleInitialization;

      final googleUser = await googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Google sign-in did not return an ID token.',
        );
      }

      // Supabase requires a Google access token as well as the ID token.
      // authorizationForScopes([]) follows the current google_sign_in 7 API
      // for retrieving the already-granted client authorization without
      // unnecessarily starting a second consent flow.
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(
        const <String>[],
      );
      final accessToken = authorization?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthException(
          'Google sign-in did not return an access token.',
        );
      }

      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (_auth.currentSession == null) {
        throw const AuthException(
          'Google sign-in completed without creating a Sprout session.',
        );
      }
      return;
    } on GoogleSignInException {
      // Credential Manager may report a configuration failure as "canceled"
      // after the user has selected an account. Do not treat that as a silent
      // exit; fall through to the browser OAuth path.
    } on AuthException {
      // If Supabase rejects the native token (for example because the
      // provider configuration is not accepted), use the OAuth path instead
      // of leaving the user stranded on the login screen.
    } catch (_) {
      // Native Google is best-effort; OAuth remains the reliable fallback.
    }

    await launchSupabaseGoogleOAuth();
  }
}
