import 'package:firebase_auth/firebase_auth.dart';

import '../core/supabase/supabase_service.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static final _firebaseAuth = FirebaseAuth.instance;

  static Future<void> deleteCurrentAccount() async {
    // Phone-auth users have a Firebase identity as well as the Supabase
    // identity. Delete Firebase first; if it cannot be deleted (for
    // example because Firebase requires recent authentication), the
    // Supabase account is left intact so deletion is never partial.
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      await firebaseUser.delete();
    }

    final response = await SupabaseService.client.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Account deletion failed (${response.status})');
    }

    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {}
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
  }
}
