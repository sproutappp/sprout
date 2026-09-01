import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';

/// All auth calls go through here — screens never touch
/// `Supabase.instance.client.auth` directly.
class AuthService {
  AuthService._();

  static GoTrueClient get _auth => SupabaseService.client.auth;

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

  /// Google sign-in via Supabase OAuth. Requires the Google provider to
  /// be configured in the Supabase dashboard (Authentication > Providers)
  /// and the redirect URL registered there.
  static Future<bool> signInWithGoogle() {
    return _auth.signInWithOAuth(OAuthProvider.google);
  }
}
