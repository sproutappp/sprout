import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';

class MemoriesAppBarWidget extends StatelessWidget {
  final double scrollOffset;

  const MemoriesAppBarWidget({super.key, required this.scrollOffset});

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
            height: topPadding + 72,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'My Memories',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '42 moments you\'ve saved',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _AppBarAction(
                  icon: Icons.sort_rounded,
                  semanticLabel: 'Sort memories',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _AppBarAction(
                  icon: Icons.tune_rounded,
                  semanticLabel: 'Filter memories',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                // Bell → Notifications
                _AppBarAction(
                  icon: Icons.notifications_outlined,
                  semanticLabel: 'Notifications',
                  onTap: () => context.push(AppRoutes.notificationsScreen),
                  hasBadge: true,
                ),
                const SizedBox(width: 8),
                // User avatar → Profile
                GestureDetector(
                  onTap: () => context.go(AppRoutes.profileScreen),
                  child: Container(
                    width: 36,
                    height: 36,
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
                            size: 18,
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
  final String semanticLabel;
  final VoidCallback onTap;
  final bool hasBadge;

  const _AppBarAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark.withAlpha(179),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: AppTheme.textSecondary),
              if (hasBadge)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.backgroundDark,
                        width: 1.0,
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
