import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import './widgets/memories_app_bar_widget.dart';
import './widgets/memories_grid_widget.dart';
import './widgets/memories_search_filter_widget.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  String _searchQuery = '';
  String _activeFilter = 'All';

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

  List<MemoryItem> get _filteredMemories {
    return allMemories.where((m) {
      // Filter by type
      final matchesFilter =
          _activeFilter == 'All' ||
          (_activeFilter == 'Photos' && m.type == MemoryType.photo) ||
          (_activeFilter == 'Videos' && m.type == MemoryType.video) ||
          (_activeFilter == 'Stories' && m.type == MemoryType.story);

      // Filter by search
      final matchesSearch =
          _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.circle.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final filtered = _filteredMemories;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
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
          MemoriesAppBarWidget(scrollOffset: _scrollOffset),

          // Scrollable content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Space for app bar
              const SliverToBoxAdapter(child: SizedBox(height: 88)),

              // Search + Filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
                  child: MemoriesSearchFilterWidget(
                    searchQuery: _searchQuery,
                    activeFilter: _activeFilter,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
                    onFilterChanged: (f) => setState(() => _activeFilter = f),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Memories grid with month groupings
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
                  child: MemoriesGridWidget(memories: filtered),
                ),
              ),

              // Bottom padding for nav bar
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 100)),
            ],
          ),

          // FAB — Capture Memory
          Positioned(
            bottom: bottomPadding + 88,
            right: 20,
            child: const _CaptureMemoryFab(),
          ),
        ],
      ),
    );
  }
}

class _CaptureMemoryFab extends StatefulWidget {
  const _CaptureMemoryFab();

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
      onTap: () {
        context.push('/create-memory-screen');
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
