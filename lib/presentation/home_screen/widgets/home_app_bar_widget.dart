import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';

class HomeAppBarWidget extends StatelessWidget {
  final double scrollOffset;

  const HomeAppBarWidget({super.key, required this.scrollOffset});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final blurOpacity = (scrollOffset / 60).clamp(0.0, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20 * blurOpacity,
            sigmaY: 20 * blurOpacity,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: topPadding + 64,
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withOpacity(0.5 * blurOpacity),
              border: scrollOffset > 10
                  ? const Border(
                      bottom: BorderSide(color: AppTheme.outline, width: 0.5),
                    )
                  : null,
            ),
            padding: EdgeInsets.only(top: topPadding, left: 20, right: 20),
            child: Row(
              children: [
                // Logo
                Image.asset(
                  'assets/images/logosprout-1787939643364.png',
                  height: 32,
                  fit: BoxFit.contain,
                  semanticLabel: 'Sprout',
                ),

                const Spacer(),

                // Notification bell
                _AppBarAction(
                  icon: Icons.notifications_outlined,
                  hasBadge: true,
                  semanticLabel: 'Notifications — 3 new',
                  onTap: () => context.push(AppRoutes.notificationsScreen),
                ),

                const SizedBox(width: 10),

                // Profile avatar
                GestureDetector(
                  onTap: () => context.go(AppRoutes.profileScreen),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryGreen.withAlpha(128),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://images.pexels.com/photos/3763188/pexels-photo-3763188.jpeg?w=100',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.surfaceVariantDark,
                          child: const Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final bool hasBadge;
  final String semanticLabel;
  final VoidCallback onTap;

  const _AppBarAction({
    required this.icon,
    required this.hasBadge,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark.withAlpha(179),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              if (hasBadge)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.backgroundDark,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
