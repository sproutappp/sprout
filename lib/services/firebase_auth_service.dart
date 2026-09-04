import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Phone Authentication.
///
/// Firebase is responsible for verifying the user's phone number.
/// After verification, the Firebase ID token can be used by
/// Supabase's Firebase third-party authentication integration.
class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static bool get isSignedIn => currentUser != null;

  /// Sends an SMS OTP to [phoneNumber].
  ///
  /// [phoneNumber] must be in E.164 format, for example:
  /// +919876543210
  static Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerification,
    void Function(String verificationId)? onAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      verificationCompleted: (PhoneAuthCredential credential) async {
        if (onAutoVerification != null) {
          onAutoVerification(credential);
        } else {
          await _auth.signInWithCredential(credential);
        }
      },

      verificationFailed: onVerificationFailed,

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        onAutoRetrievalTimeout?.call(verificationId);
      },
    );
  }

  /// Verifies the SMS OTP entered by the user.
  static Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return _auth.signInWithCredential(credential);
  }

  /// Returns the Firebase ID token for the currently signed-in user.
  ///
  /// Supabase will use this token once Firebase has been configured
  /// as a Third-Party Auth provider.
  static Future<String?> getIdToken() async {
    return _auth.currentUser?.getIdToken();
  }

  static Future<void> signOut() {
    return _auth.signOut();
  }
}
