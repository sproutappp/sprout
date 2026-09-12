import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/memory.dart';
import '../../routes/app_routes.dart';
import '../../services/discover_refresh_bus.dart';
import '../../services/memories_repository.dart';
import '../../theme/app_theme.dart';
import '../memories_screen/widgets/memories_grid_widget.dart'
    show MemoryItem, MemoryPrivacy, MemoryType;

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  bool _loadFailed = false;
  List<Memory> _memories = [];
  String _selectedTab = 'For You';

  @override
  void initState() {
    super.initState();
    DiscoverRefreshBus.signal.addListener(_onRefreshRequested);
    _load();
  }

  @override
  void dispose() {
    DiscoverRefreshBus.signal.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }

    try {
      final memories = await MemoriesRepository.fetchPublicMemories();
      if (!mounted) return;
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('DiscoverScreen: fetchPublicMemories failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  void _openMemory(Memory memory) {
    final item = MemoryItem(
      id: memory.id,
      title: memory.caption?.isNotEmpty == true
          ? memory.caption!
          : 'A shared memory',
      date:
          '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}',
      imageUrl: memory.imageUrl,
      semanticLabel: 'Public memory photo',
      circle: 'Public',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
      type: MemoryType.photo,
    );
    context.push(AppRoutes.memoryDetailScreen, extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBody: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryGreen,
              backgroundColor: AppTheme.surfaceDark,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: top + 12)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discover',
                                  style: GoogleFonts.manrope(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Moments worth remembering, from\naround the world.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariantDark,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.textPrimary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _DiscoverTab(
                            label: 'For You',
                            selected: _selectedTab == 'For You',
                            onTap: () => setState(() => _selectedTab = 'For You'),
                          ),
                          const SizedBox(width: 8),
                          _DiscoverTab(
                            label: 'Nearby',
                            selected: _selectedTab == 'Nearby',
                            onTap: () => setState(() => _selectedTab = 'Nearby'),
                          ),
                          const SizedBox(width: 8),
                          _DiscoverTab(
                            label: 'Trending',
                            selected: _selectedTab == 'Trending',
                            onTap: () => setState(() => _selectedTab = 'Trending'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  if (_loadFailed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 60,
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Couldn't load Discover right now.",
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_memories.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 70,
                        ),
                        child: Text(
                          'Public memories will appear here when people share them.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final memory = _memories[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PublicMemoryCard(
                                memory: memory,
                                onTap: () => _openMemory(memory),
                              ),
                            );
                          },
                          childCount: _memories.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 100,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DiscoverTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.backgroundDark : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PublicMemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const _PublicMemoryCard({required this.memory, required this.onTap});

  String _timeAgo() {
    final difference = DateTime.now().difference(memory.createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final caption = memory.caption?.trim() ?? '';
    final parts = caption.split(' — ');
    final title = parts.first.trim().isEmpty ? 'A shared memory' : parts.first.trim();
    final description = parts.length > 1 ? parts.sublist(1).join(' — ').trim() : '';
    final contributor = memory.contributor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surfaceVariantDark),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.12,
                  child: CachedNetworkImage(
                    imageUrl: memory.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.surfaceVariantDark),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surfaceVariantDark,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark.withAlpha(210),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public, size: 11, color: AppTheme.cyanAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Public',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (memory.location?.trim().isNotEmpty == true)
                  Positioned(
                    left: 12,
                    bottom: 10,
                    right: 12,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            memory.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppTheme.surfaceVariantDark,
                        backgroundImage: contributor?.avatarUrl?.isNotEmpty == true
                            ? CachedNetworkImageProvider(contributor!.avatarUrl!)
                            : null,
                        child: contributor?.avatarUrl?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.person_outline, size: 17, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          contributor?.displayName ?? 'Sprout member',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(),
                        style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        height: 1.45,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 15, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.textMuted),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryGreen),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
