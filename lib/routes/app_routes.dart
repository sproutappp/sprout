import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/home_screen/home_screen.dart';
import '../presentation/memories_screen/memories_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/create_memory_screen/create_memory_screen_fixed.dart';
import '../presentation/memory_detail_screen/memory_detail_screen.dart';
import '../presentation/circles_screen/circles_screen_with_cover.dart';
import '../presentation/circle_detail_screen/circle_detail_screen.dart';
import '../presentation/memories_screen/widgets/memories_grid_widget.dart';
import '../presentation/discover_screen/discover_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/edit_profile_screen/edit_profile_screen.dart';
import '../presentation/member_profile_screen/member_profile_screen.dart';
import '../presentation/notifications_screen/notifications_screen.dart';
import '../presentation/privacy_policy_screen/privacy_policy_screen.dart';
import '../presentation/settings_screen/settings_screen.dart';
import '../presentation/join_circle_screen/join_circle_screen.dart';
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
  static const String privacyPolicyScreen = '/privacy-policy-screen';
  static const String settingsScreen = '/settings-screen';
  static const String joinCircleScreen = '/join-circle-screen';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  routes: [
    GoRoute(path: AppRoutes.initial, builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.onboardingScreen, builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.signUpLoginScreen, builder: (context, state) => const SignUpLoginScreen()),
    GoRoute(
      path: AppRoutes.createMemoryScreen,
      builder: (context, state) => CreateMemoryScreenFixed(initialCircleId: state.extra as String?),
    ),
    GoRoute(
      path: AppRoutes.joinCircleScreen,
      builder: (context, state) => JoinCircleScreen(initialToken: state.extra as String?),
    ),
    GoRoute(
      path: '/join/:token',
      builder: (context, state) => JoinCircleScreen(initialToken: state.pathParameters['token'], autoJoin: true),
    ),
    GoRoute(
      path: AppRoutes.memoryDetailScreen,
      builder: (context, state) => MemoryDetailScreen(memory: state.extra as MemoryItem),
    ),
    GoRoute(
      path: AppRoutes.circleDetailScreen,
      builder: (context, state) => CircleDetailScreen(circleId: state.extra as String?),
    ),
    GoRoute(path: AppRoutes.editProfileScreen, builder: (context, state) => const EditProfileScreen()),
    GoRoute(
      path: AppRoutes.memberProfileScreen,
      builder: (context, state) {
        final extra = state.extra as Map<String, String?>?;
        return MemberProfileScreen(memberId: extra?['memberId'], memberName: extra?['memberName'], memberAvatarUrl: extra?['memberAvatarUrl']);
      },
    ),
    GoRoute(path: AppRoutes.privacyPolicyScreen, builder: (context, state) => const PrivacyPolicyScreen()),
    GoRoute(path: AppRoutes.settingsScreen, builder: (context, state) => const SettingsScreen()),
    GoRoute(path: AppRoutes.notificationsScreen, builder: (context, state) => const NotificationsScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: AppRoutes.homeScreen, builder: (context, state) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: AppRoutes.memoriesScreen, builder: (context, state) => const MemoriesScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: AppRoutes.discoverScreen, builder: (context, state) => const DiscoverScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: AppRoutes.circlesScreen, builder: (context, state) => const CirclesScreenWithCover())]),
        StatefulShellBranch(routes: [GoRoute(path: AppRoutes.profileScreen, builder: (context, state) => const ProfileScreen())]),
      ],
    ),
  ],
);
