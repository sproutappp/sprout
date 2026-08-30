import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import './widgets/onboarding_background_widget.dart';
import './widgets/onboarding_cta_widget.dart';
import './widgets/onboarding_hero_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // TODO: Replace with [Riverpod/Bloc] for production
  late AnimationController _heroController;
  late AnimationController _contentController;
  late AnimationController _ctaController;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _ctaFade;
  late Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic),
        );

    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    _ctaFade = CurvedAnimation(
      parent: _ctaController,
      curve: Curves.easeOutCubic,
    );
    _ctaSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _ctaController, curve: Curves.easeOutCubic),
        );

    _runEntrance();
  }

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _heroController.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    _contentController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _ctaController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _contentController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    context.push(AppRoutes.signUpLoginScreen);
  }

  void _onSignIn() {
    context.push(AppRoutes.signUpLoginScreen);
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
          // Animated particle background
          const OnboardingBackgroundWidget(),

          // Main content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 480 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 40 : 28,
                    0,
                    isTablet ? 40 : 28,
                    bottomPadding + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Flexible spacer — pushes hero toward golden ratio
                      const Spacer(flex: 2),

                      // Hero: logo + tagline + glow
                      FadeTransition(
                        opacity: _heroFade,
                        child: SlideTransition(
                          position: _heroSlide,
                          child: const OnboardingHeroWidget(),
                        ),
                      ),

                      const Spacer(flex: 1),

                      // Value propositions
                      FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: const _ValuePropsWidget(),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // CTAs
                      FadeTransition(
                        opacity: _ctaFade,
                        child: SlideTransition(
                          position: _ctaSlide,
                          child: OnboardingCtaWidget(
                            onGetStarted: _onGetStarted,
                            onSignIn: _onSignIn,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Terms
                      FadeTransition(
                        opacity: _ctaFade,
                        child: Text(
                          'By continuing, you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: AppTheme.textDisabled,
                            height: 1.5,
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

class _ValuePropsWidget extends StatelessWidget {
  const _ValuePropsWidget();

  @override
  Widget build(BuildContext context) {
    const props = [
      (Icons.photo_library_outlined, 'Capture moments that matter'),
      (Icons.group_outlined, 'Share with your trusted circles'),
      (Icons.explore_outlined, 'Discover stories from the world'),
    ];

    return Column(
      children: props.asMap().entries.map((entry) {
        final i = entry.key;
        final prop = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: i < props.length - 1 ? 14 : 0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenGlow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withAlpha(51),
                    width: 0.5,
                  ),
                ),
                child: Icon(prop.$1, size: 17, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 14),
              Text(
                prop.$2,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
