import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../onboarding_screen/widgets/onboarding_background_widget.dart';
import './widgets/auth_demo_credentials_widget.dart';
import './widgets/auth_form_widget.dart';
import './widgets/auth_header_widget.dart';

class SignUpLoginScreen extends StatefulWidget {
  const SignUpLoginScreen({super.key});

  @override
  State<SignUpLoginScreen> createState() => _SignUpLoginScreenState();
}

class _SignUpLoginScreenState extends State<SignUpLoginScreen>
    with SingleTickerProviderStateMixin {
  // TODO: Replace with [Riverpod/Bloc] for production
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  final _loginEmailController = TextEditingController(text: 'maya@sprout.app');
  final _loginPasswordController = TextEditingController(text: 'Sprout2026!');
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

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
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
    _slideController.forward(from: 0);
  }

  Future<void> _onSubmit() async {
    final formKey = _isLogin ? _loginFormKey : _signupFormKey;
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // TODO: Replace with real auth API call
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Mock credential check
    final email = _isLogin
        ? _loginEmailController.text.trim()
        : _signupEmailController.text.trim();
    final password = _isLogin
        ? _loginPasswordController.text
        : _signupPasswordController.text;

    if (_isLogin && (email != 'maya@sprout.app' || password != 'Sprout2026!')) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Invalid credentials — use the demo account below to sign in';
      });
      return;
    }

    setState(() => _isLoading = false);
    context.go(AppRoutes.homeScreen);
  }

  void _onGoogleSignIn() {
    // TODO: Replace with real Google Sign-In
    context.go(AppRoutes.homeScreen);
  }

  void _fillDemoCredentials(String email, String password) {
    setState(() {
      _loginEmailController.text = email;
      _loginPasswordController.text = password;
    });
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

                      // Tab toggle
                      _AuthToggle(isLogin: _isLogin, onToggle: _toggleMode),

                      const SizedBox(height: 28),

                      // Error message
                      if (_errorMessage != null) ...[
                        _ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      // Form
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: AuthFormWidget(
                            isLogin: _isLogin,
                            isLoading: _isLoading,
                            loginEmailController: _loginEmailController,
                            loginPasswordController: _loginPasswordController,
                            signupNameController: _signupNameController,
                            signupEmailController: _signupEmailController,
                            signupPasswordController: _signupPasswordController,
                            signupConfirmController: _signupConfirmController,
                            loginFormKey: _loginFormKey,
                            signupFormKey: _signupFormKey,
                            onSubmit: _onSubmit,
                            onGoogleSignIn: _onGoogleSignIn,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Demo credentials (login mode only)
                      if (_isLogin)
                        AuthDemoCredentialsWidget(onUse: _fillDemoCredentials),

                      const SizedBox(height: 24),

                      // Toggle link
                      GestureDetector(
                        onTap: _toggleMode,
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin
                                    ? "Don't have an account? "
                                    : 'Already have an account? ',
                              ),
                              TextSpan(
                                text: _isLogin ? 'Sign Up' : 'Sign In',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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

class _AuthToggle extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _AuthToggle({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline, width: 0.5),
      ),
      child: Stack(
        children: [
          // Sliding indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isLogin ? null : onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isLogin ? Colors.black : AppTheme.textMuted,
                      ),
                      child: const Text('Sign In'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: !isLogin ? null : onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: !isLogin ? Colors.black : AppTheme.textMuted,
                      ),
                      child: const Text('Sign Up'),
                    ),
                  ),
                ),
              ),
            ],
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
