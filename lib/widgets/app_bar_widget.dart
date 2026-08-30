import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// V3 — Glassmorphism AppBar
// LOCKED: BackdropFilter blur, transparent, content shows through

class SproutAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogo;
  final bool hasBlur;
  final double elevation;

  const SproutAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showLogo = false,
    this.hasBlur = true,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget bar = Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: hasBlur
            ? AppTheme.backgroundDark.withAlpha(153)
            : Colors.transparent,
        border: hasBlur
            ? const Border(
                bottom: BorderSide(color: AppTheme.outline, width: 0.5),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ] else if (Navigator.of(context).canPop()) ...[
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.outline, width: 0.5),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child:
                  titleWidget ??
                  (showLogo
                      ? Image.asset(
                          'assets/images/logosprout-1787939643364.png',
                          height: 28,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          semanticLabel:
                              'Sprout logo — continuous S loop with central dot',
                        )
                      : Text(
                          title ?? '',
                          style: theme.textTheme.headlineSmall,
                        )),
            ),
            if (actions != null)
              Row(mainAxisSize: MainAxisSize.min, children: actions!),
          ],
        ),
      ),
    );

    if (hasBlur) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bar,
        ),
      );
    }

    return bar;
  }
}

// Compact icon action button used in AppBar
class AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasBadge;
  final String? semanticLabel;

  const AppBarIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.hasBadge = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              if (hasBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
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
