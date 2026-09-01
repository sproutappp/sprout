import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/home_screen/home_screen.dart';
import '../presentation/memories_screen/memories_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/create_memory_screen/create_memory_screen.dart';
import '../presentation/memory_detail_screen/memory_detail_screen.dart';
import '../presentation/circles_screen/circles_screen.dart';
import '../presentation/circle_detail_screen/circle_detail_screen.dart';
import '../presentation/memories_screen/widgets/memories_grid_widget.dart';
import '../presentation/discover_screen/discover_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/edit_profile_screen/edit_profile_screen.dart';
import '../presentation/member_profile_screen/member_profile_screen.dart';
import '../presentation/notifications_screen/notifications_screen.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  static const String initial = '/';
  static const String onboardingScreen = '/onboarding-screen';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String homeScreen = '/home-screen';
  static const String memoriesScreen = '/memories-screen';
  static const String createMemoryScreen = '/create-memory-screen';
  static const String memoryDetailScreen = '/memory-detail-screen';
  static const String circlesScreen = '/circles-screen';
  static const String circleDetailScreen = '/circle-detail-screen';
  static const String discoverScreen = '/discover-screen';
  static const String profileScreen = '/profile-screen';
  static const String editProfileScreen = '/edit-profile-screen';
  static const String memberProfileScreen = '/member-profile-screen';
  static const String notificationsScreen = '/notifications-screen';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  routes: [
    // ── Root: redirects to onboarding ────────────────────────────────────
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    ),

    // ── Auth screens (outside shell) ─────────────────────────────────────
    GoRoute(
      path: AppRoutes.onboardingScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.signUpLoginScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignUpLoginScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
          );
        },
      ),
    ),

    // ── Create Memory (outside shell — full screen modal feel) ────────────
    GoRoute(
      path: AppRoutes.createMemoryScreen,
      pageBuilder: (context, state) {
        final circleId = state.extra as String?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: CreateMemoryScreen(initialCircleId: circleId),
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        );
      },
    ),

    // ── Memory Detail (outside shell — full screen immersive) ─────────────
    GoRoute(
      path: AppRoutes.memoryDetailScreen,
      pageBuilder: (context, state) {
        final memory = state.extra as MemoryItem;
        return CustomTransitionPage(
          key: state.pageKey,
          child: MemoryDetailScreen(memory: memory),
          transitionDuration: const Duration(milliseconds: 340),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              ),
            );
          },
        );
      },
    ),

    // ── Circle Detail (outside shell — full screen) ───────────────────────
    GoRoute(
      path: AppRoutes.circleDetailScreen,
      pageBuilder: (context, state) {
        final circleId = state.extra as String?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: CircleDetailScreen(circleId: circleId),
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              ),
            );
          },
        );
      },
    ),

    // ── Edit Profile (outside shell) ──────────────────────────────────────
    GoRoute(
      path: AppRoutes.editProfileScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const EditProfileScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
          );
        },
      ),
    ),

    // ── Member Profile (outside shell — full screen) ───────────────────────
    GoRoute(
      path: AppRoutes.memberProfileScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String?>?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: MemberProfileScreen(
            memberId: extra?['memberId'],
            memberName: extra?['memberName'],
            memberAvatarUrl: extra?['memberAvatarUrl'],
          ),
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1.0, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              ),
            );
          },
        );
      },
    ),

    // ── Notifications (outside shell — full screen) ────────────────────────
    GoRoute(
      path: AppRoutes.notificationsScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const NotificationsScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
          );
        },
      ),
    ),

    // ── Shell: authenticated app with bottom nav ──────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.homeScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
          ],
        ),
        // Branch 1 — Memories
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.memoriesScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: MemoriesScreen()),
            ),
          ],
        ),
        // Branch 2 — Discover
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.discoverScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DiscoverScreen()),
            ),
          ],
        ),
        // Branch 3 — Circles
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.circlesScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CirclesScreen()),
            ),
          ],
        ),
        // Branch 4 — Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profileScreen,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen()),
            ),
          ],
        ),
      ],
    ),
  ],
);
