import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/notifications_repository.dart';
import '../../../widgets/current_user_avatar_widget.dart';

class HomeAppBarWidget extends StatefulWidget {
  final double scrollOffset;

  const HomeAppBarWidget({super.key, required this.scrollOffset});

  @override
  State<HomeAppBarWidget> createState() => _HomeAppBarWidgetState();
}

class _HomeAppBarWidgetState extends State<HomeAppBarWidget>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 10);

  Timer? _refreshTimer;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationsRepository.fetchUnreadCount();
      if (!mounted) return;
      if (count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {
      // Keep the current badge when a transient count request fails.
    }
  }

  Future<void> _openNotifications(BuildContext context) async {
    await context.push(AppRoutes.notificationsScreen);
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final blurOpacity = (widget.scrollOffset / 60).clamp(0.0, 1.0);
    final badgeText = _unreadCount > 99 ? '99+' : '$_unreadCount';
    final semanticLabel = _unreadCount > 0
        ? 'Notifications — $_unreadCount unread'
        : 'Notifications';

    return Positioned(
      top: -widget.scrollOffset,
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
              border: widget.scrollOffset > 10
                  ? const Border(
                      bottom: BorderSide(color: AppTheme.outline, width: 0.5),
                    )
                  : null,
            ),
            padding: EdgeInsets.only(top: topPadding, left: 20, right: 20),
            child: Row(
              children: [
                // Canonical Sprout logo
                SvgPicture.asset(
                  'assets/images/sprout_logo.svg',
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                  semanticsLabel: 'Sprout',
                ),

                const Spacer(),

                // Notification bell with the exact unread count.
                _AppBarAction(
                  icon: Icons.notifications_outlined,
                  badgeText: _unreadCount > 0 ? badgeText : null,
                  semanticLabel: semanticLabel,
                  onTap: () => _openNotifications(context),
                ),

                const SizedBox(width: 10),

                // Profile avatar
                CurrentUserAvatarWidget(
                  size: 38,
                  onTap: () => context.go(AppRoutes.profileScreen),
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
  final String? badgeText;
  final String semanticLabel;
  final VoidCallback onTap;

  const _AppBarAction({
    required this.icon,
    required this.badgeText,
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
              if (badgeText != null)
                Positioned(
                  top: 3,
                  right: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppTheme.backgroundDark,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1,
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