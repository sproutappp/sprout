import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (defaultTargetPlatform == TargetPlatform.android) {
      final googleSignIn = GoogleSignIn.instance;

      _googleInitialization ??= googleSignIn.initialize(
        // This is the web OAuth client from google-services.json. Supabase
        // validates the Google ID token against the same client configuration.
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

      // google_sign_in 7 separates authentication from authorization.
      // Supabase requires a Google access token as well as the ID token.
      final authorization = await googleUser.authorizationClient.authorizeScopes(
        const <String>['email', 'profile'],
      );

      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    }

    final launched = await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'app.sprout.auth://login-callback/',
    );
    if (!launched) {
      throw const AuthException('Could not start Google sign-in.');
    }
  }
}
