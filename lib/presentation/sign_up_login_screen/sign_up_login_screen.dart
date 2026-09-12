import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding_screen/widgets/onboarding_background_widget.dart';
import './widgets/auth_form_widget.dart';
import './widgets/auth_header_widget.dart';

class SignUpLoginScreen extends StatefulWidget {
  const SignUpLoginScreen({super.key});

  @override
  State<SignUpLoginScreen> createState() => _SignUpLoginScreenState();
}

class _SignUpLoginScreenState extends State<SignUpLoginScreen>
    with SingleTickerProviderStateMixin {
  String? _errorMessage;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnim = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _errorMessage = null);
    try {
      await AuthService.signInWithGoogle();
      // Supabase OAuth completes via deep link redirect; the
      // onAuthStateChange listener (wired at the router/app level)
      // should handle navigation once the session lands. If this
      // screen is still mounted after the redirect flow returns
      // control here, fall through without forcing navigation.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  /// Called once Firebase has genuinely verified the phone number —
  /// that part is real, not faked.
  ///
  /// IMPORTANT — read before changing this: there is currently no
  /// Supabase session for phone-verified users. Every RLS-protected
  /// query in this app (circles, memories, notifications, reactions,
  /// comments — all of it) checks Supabase's own auth.uid(), which will
  /// be null here. Bridging Firebase identity into a real Supabase
  /// session is a genuine open architecture question, not a missing
  /// dashboard toggle — see the conversation/report for why Supabase's
  /// documented Third-Party Auth mechanism can't just be turned on
  /// without further decisions. Navigating home is still correct for
  /// now (the login itself succeeded), but screens past this point
  /// will not show this user's real data until that's resolved.
  void _onPhoneVerified() {
    if (!mounted) return;
    context.go(AppRoutes.homeScreen);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          const OnboardingBackgroundWidget(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 480 : double.infinity,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 40 : 24,
                    24,
                    isTablet ? 40 : 24,
                    bottomPadding + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariantDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.outline,
                                width: 0.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Header: logo + title
                      const AuthHeaderWidget(),

                      const SizedBox(height: 32),

                      // Error message
                      if (_errorMessage != null) ...[
                        _ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      // Google + phone OTP login options
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: AuthFormWidget(
                            onGoogleSignIn: _onGoogleSignIn,
                            onPhoneVerified: _onPhoneVerified,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withAlpha(77), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: AppTheme.error,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
