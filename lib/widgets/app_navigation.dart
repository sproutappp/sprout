import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

// V4 — 5-item nav: Home | Memories | Discover | Circles | Profile
// Create Memory is now a floating circular FAB on each screen

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.branchIndex,
  });
}

class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation>
    with SingleTickerProviderStateMixin {
  int _selectedVisualIndex = 0;

  late AnimationController _pillController;
  late Animation<double> _pillAnimation;

  final List<_TabSpec> _tabs = const [
    _TabSpec(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'Memories',
      icon: Icons.photo_album_outlined,
      selectedIcon: Icons.photo_album_rounded,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'Discover',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'Circles',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group_rounded,
      branchIndex: 3,
    ),
    _TabSpec(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      branchIndex: 4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pillAnimation = CurvedAnimation(
      parent: _pillController,
      curve: Curves.easeOutCubic,
    );
    _pillController.forward();
  }

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  void _onTabTapped(int visualIndex) {
    final tab = _tabs[visualIndex];
    if (tab.branchIndex == null) return;

    setState(() {
      _selectedVisualIndex = visualIndex;
    });

    _pillController.forward(from: 0);

    widget.navigationShell.goBranch(
      tab.branchIndex!,
      initialLocation: tab.branchIndex == widget.navigationShell.currentIndex,
    );
  }

  int _resolveVisualIndex() {
    final currentBranch = widget.navigationShell.currentIndex;
    for (int i = 0; i < _tabs.length; i++) {
      if (_tabs[i].branchIndex == currentBranch) return i;
    }
    return _selectedVisualIndex;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final activeVisual = _resolveVisualIndex();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withAlpha(184),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.outline.withAlpha(128),
                width: 0.8,
              ),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = index == activeVisual;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabTapped(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      decoration: isSelected
                          ? BoxDecoration(
                              color: AppTheme.primaryGreenGlow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryGreen.withAlpha(77),
                                width: 0.8,
                              ),
                            )
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? tab.selectedIcon : tab.icon,
                            size: 22,
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textMuted,
                            ),
                            child: Text(tab.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
