import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import './phone_auth_widget.dart';

// V5 — Glassmorphism form fields
// LOCKED: frosted background, animated focus, semi-transparent fill

class AuthFormWidget extends StatefulWidget {
  final bool isLogin;
  final bool isLoading;
  final TextEditingController loginEmailController;
  final TextEditingController loginPasswordController;
  final TextEditingController signupNameController;
  final TextEditingController signupEmailController;
  final TextEditingController signupPasswordController;
  final TextEditingController signupConfirmController;
  final GlobalKey<FormState> loginFormKey;
  final GlobalKey<FormState> signupFormKey;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onPhoneVerified;

  const AuthFormWidget({
    super.key,
    required this.isLogin,
    required this.isLoading,
    required this.loginEmailController,
    required this.loginPasswordController,
    required this.signupNameController,
    required this.signupEmailController,
    required this.signupPasswordController,
    required this.signupConfirmController,
    required this.loginFormKey,
    required this.signupFormKey,
    required this.onSubmit,
    required this.onGoogleSignIn,
    required this.onPhoneVerified,
  });

  @override
  State<AuthFormWidget> createState() => _AuthFormWidgetState();
}

class _AuthFormWidgetState extends State<AuthFormWidget> {
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Form
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: widget.isLogin
              ? _LoginForm(
                  key: const ValueKey('login'),
                  formKey: widget.loginFormKey,
                  emailController: widget.loginEmailController,
                  passwordController: widget.loginPasswordController,
                  passwordVisible: _passwordVisible,
                  onTogglePassword: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                )
              : _SignupForm(
                  key: const ValueKey('signup'),
                  formKey: widget.signupFormKey,
                  nameController: widget.signupNameController,
                  emailController: widget.signupEmailController,
                  passwordController: widget.signupPasswordController,
                  confirmController: widget.signupConfirmController,
                  passwordVisible: _passwordVisible,
                  confirmVisible: _confirmVisible,
                  onTogglePassword: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  onToggleConfirm: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                ),
        ),

        const SizedBox(height: 20),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              disabledBackgroundColor: AppTheme.primaryGreen.withAlpha(102),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      key: const ValueKey('label'),
                      widget.isLogin ? 'Sign In' : 'Create Account',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Divider
        Row(
          children: [
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or continue with',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
          ],
        ),

        const SizedBox(height: 16),

        // Google button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: widget.onGoogleSignIn,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.outline, width: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Divider
        Row(
          children: [
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or use your phone',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
          ],
        ),

        const SizedBox(height: 16),

        // Phone OTP sign-in — self-contained, isolated from Supabase
        // (see the note in sign_up_login_screen.dart's onPhoneVerified).
        PhoneAuthWidget(onVerified: widget.onPhoneVerified),
      ],
    );
  }
}

// ── Login Form ────────────────────────────────────────────────────────────────
class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;

  const _LoginForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.onTogglePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _GlassField(
            controller: emailController,
            label: 'Email address',
            hint: 'your@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.alternate_email_rounded,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GlassField(
            controller: passwordController,
            label: 'Password',
            hint: '••••••••',
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onSuffixTap: onTogglePassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signup Form ───────────────────────────────────────────────────────────────
class _SignupForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool passwordVisible;
  final bool confirmVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;

  const _SignupForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.passwordVisible,
    required this.confirmVisible,
    required this.onTogglePassword,
    required this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _GlassField(
            controller: nameController,
            label: 'Full name',
            hint: 'Maya Patel',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GlassField(
            controller: emailController,
            label: 'Email address',
            hint: 'your@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.alternate_email_rounded,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GlassField(
            controller: passwordController,
            label: 'Password',
            hint: 'Min 8 characters',
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onSuffixTap: onTogglePassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GlassField(
            controller: confirmController,
            label: 'Confirm password',
            hint: 'Repeat your password',
            obscureText: !confirmVisible,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: confirmVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onSuffixTap: onToggleConfirm,
            validator: (v) {
              if (v != passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ── Glassmorphism Field ───────────────────────────────────────────────────────
class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withAlpha(38),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            filled: true,
            fillColor: _focused
                ? AppTheme.surfaceVariantDark.withAlpha(230)
                : AppTheme.surfaceVariantDark.withAlpha(153),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                widget.prefixIcon,
                size: 18,
                color: _focused ? AppTheme.primaryGreen : AppTheme.textMuted,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: widget.suffixIcon != null
                ? GestureDetector(
                    onTap: widget.onSuffixTap,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        widget.suffixIcon,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            labelStyle: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: _focused ? AppTheme.primaryGreen : AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
            hintStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: AppTheme.textDisabled,
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppTheme.error,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
