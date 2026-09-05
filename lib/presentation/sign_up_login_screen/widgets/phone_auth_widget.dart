import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/firebase_auth_service.dart';
import '../../../theme/app_theme.dart';

/// Phone-number OTP sign-in via Firebase. Self-contained — owns its own
/// phone/OTP state so the parent screen only needs one callback (fired
/// once Firebase has actually verified the number).
///
/// Deliberately does NOT touch Supabase at all. See the note above
/// [onVerified] in the parent screen for why — this is a real, open
/// architecture question, not an oversight.
class PhoneAuthWidget extends StatefulWidget {
  final VoidCallback onVerified;

  const PhoneAuthWidget({super.key, required this.onVerified});

  @override
  State<PhoneAuthWidget> createState() => _PhoneAuthWidgetState();
}

enum _PhoneAuthStage { entry, otp }

class _PhoneAuthWidgetState extends State<PhoneAuthWidget> {
  _PhoneAuthStage _stage = _PhoneAuthStage.entry;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  String? _e164Phone;
  String? _errorMessage;

  bool _isSendingOtp = false; // guards against duplicate sendOtp calls
  bool _isVerifying = false;

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const _resendCooldownSeconds = 30;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// India-only E.164 formatting for now: a fixed +91 prefix plus a
  /// 10-digit mobile number. Good enough for the actual target market;
  /// a full country picker would be over-building for what's needed today.
  String? _toE164(String rawInput) {
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return null;
    return '+91$digits';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSecondsLeft -= 1;
        if (_resendSecondsLeft <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    if (_isSendingOtp) return; // duplicate-request guard

    final e164 = _toE164(_phoneController.text);
    if (e164 == null) {
      setState(() => _errorMessage = 'Enter a valid 10-digit phone number.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuthService.sendOtp(
        phoneNumber: e164,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _e164Phone = e164;
            _stage = _PhoneAuthStage.otp;
            _isSendingOtp = false;
          });
          _startResendCooldown();
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _isSendingOtp = false;
            // Real Firebase error message, not a generic one — e.g.
            // "The provided phone number is not valid" — genuinely
            // useful to the person typing it in.
            _errorMessage = e.message ?? 'Could not send the code. Try again.';
          });
        },
        onAutoVerification: (credential) async {
          // Android may auto-detect the SMS and complete verification
          // without the user ever typing a code. Handle it explicitly
          // here (rather than relying on the service's internal
          // fallback) so the UI actually reacts to it.
          if (!mounted) return;
          setState(() => _isVerifying = true);
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            widget.onVerified();
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _isVerifying = false;
              _errorMessage = "Auto-verification failed — enter the code manually.";
            });
          }
        },
        onAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          // Just means auto-read timed out — the manual OTP field
          // (already shown via codeSent) still works fine.
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _errorMessage = "Couldn't send the code — check your connection and try again.";
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return; // duplicate-request guard
    final code = _otpController.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _errorMessage = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuthService.verifyOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      if (!mounted) return;
      widget.onVerified();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message ?? 'Incorrect code — try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = "Couldn't verify that code — try again.";
      });
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _stage = _PhoneAuthStage.entry;
      _otpController.clear();
      _verificationId = null;
      _errorMessage = null;
      _resendSecondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _stage == _PhoneAuthStage.entry
          ? _buildEntryStage(key: const ValueKey('phone-entry'))
          : _buildOtpStage(key: const ValueKey('phone-otp')),
    );
  }

  Widget _buildEntryStage({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          _InlineError(message: _errorMessage!),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outline, width: 0.8),
            color: AppTheme.surfaceVariantDark.withAlpha(153),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Text(
                  '🇮🇳 +91',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: AppTheme.outline),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '98765 43210',
                    hintStyle: TextStyle(color: AppTheme.textDisabled),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _isSendingOtp ? null : _sendOtp,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.outline, width: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStage({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code sent to $_e164Phone',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (_errorMessage != null) ...[
          _InlineError(message: _errorMessage!),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: const TextStyle(color: AppTheme.textDisabled),
            filled: true,
            fillColor: AppTheme.surfaceVariantDark.withAlpha(153),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              disabledBackgroundColor: AppTheme.primaryGreen.withAlpha(102),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text(
                    'Verify',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _changeNumber,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text(
                'Change number',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: (_resendSecondsLeft > 0 || _isSendingOtp)
                  ? null
                  : _sendOtp,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                _resendSecondsLeft > 0
                    ? 'Resend in ${_resendSecondsLeft}s'
                    : 'Resend OTP',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _resendSecondsLeft > 0
                      ? AppTheme.textDisabled
                      : AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withAlpha(77), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 15, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                color: AppTheme.error,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
