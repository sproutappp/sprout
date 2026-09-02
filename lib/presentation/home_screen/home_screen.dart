import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import './widgets/home_app_bar_widget.dart';
import './widgets/home_circles_strip_widget.dart';
import './widgets/home_discover_teaser_widget.dart';
import './widgets/home_greeting_widget.dart';
import './widgets/home_recent_memories_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // TODO: Replace with [Riverpod/Bloc] for production
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  // Bumping this forces HomeRecentMemoriesWidget and HomeCirclesStripWidget
  // to fully rebuild (new key -> new State -> initState re-runs -> re-fetch)
  // after something changes elsewhere (e.g. a new memory was captured).
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Subtle background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.0,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),

          // Glassmorphism AppBar
          HomeAppBarWidget(scrollOffset: _scrollOffset),

          // Scrollable content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top space for app bar
              const SliverToBoxAdapter(child: SizedBox(height: 80)),

              // Greeting
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 32 : 20,
                    16,
                    isTablet ? 32 : 20,
                    0,
                  ),
                  child: const HomeGreetingWidget(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Recent memories — horizontal scroll
              SliverToBoxAdapter(
                child: HomeRecentMemoriesWidget(
                  key: ValueKey('recent_memories_$_refreshKey'),
                  isTablet: isTablet,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Circles activity strip
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
                  child: HomeCirclesStripWidget(
                    key: ValueKey('circles_strip_$_refreshKey'),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Discover teaser
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
                  child: HomeDiscoverTeaserWidget(isTablet: isTablet),
                ),
              ),

              // Bottom padding for nav bar
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 100)),
            ],
          ),

          // Extended FAB — Capture Memory
          Positioned(
            bottom: bottomPadding + 88,
            right: 20,
            child: _CaptureMemoryFab(onSaved: _refresh),
          ),
        ],
      ),
    );
  }
}

class _CaptureMemoryFab extends StatefulWidget {
  final VoidCallback onSaved;

  const _CaptureMemoryFab({required this.onSaved});

  @override
  State<_CaptureMemoryFab> createState() => _CaptureMemoryFabState();
}

class _CaptureMemoryFabState extends State<_CaptureMemoryFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.90,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () async {
        final saved = await context.push<bool>(AppRoutes.createMemoryScreen);
        if (saved == true) widget.onSaved();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withAlpha(102),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.black),
        ),
      ),
    );
  }
}
