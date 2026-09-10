import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Clean "My Memories" header — title + a real (not hardcoded) count of
/// the signed-in user's memories. Notification/settings/avatar controls
/// were removed: those belong on their own screens (Home, Profile), not
/// duplicated here.
class MemoriesAppBarWidget extends StatelessWidget {
  final double scrollOffset;
  final int memoryCount;

  const MemoriesAppBarWidget({
    super.key,
    required this.scrollOffset,
    required this.memoryCount,
  });

  /// Total height this header actually occupies, including the device's
  /// top safe-area inset — the scroll content below needs to reserve
  /// exactly this much space (see MemoriesScreen), or the header (drawn
  /// on top, positioned absolutely) will overlap whatever comes right
  /// after it.
  static double heightFor(BuildContext context) =>
      MediaQuery.of(context).padding.top + 64;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final blurOpacity = (scrollOffset / 60).clamp(0.0, 1.0);
    final subtitle = memoryCount == 0
        ? 'No moments saved yet'
        : memoryCount == 1
            ? '1 moment you\'ve saved'
            : '$memoryCount moments you\'ve saved';

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMuted,
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
