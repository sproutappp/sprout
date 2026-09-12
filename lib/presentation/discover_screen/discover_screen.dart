import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/memory.dart';
import '../../services/memories_repository.dart';
import '../../services/discover_refresh_bus.dart';
import '../memories_screen/widgets/memories_grid_widget.dart' show MemoryItem, MemoryPrivacy, MemoryType;

/// Discover shows memories the uploader explicitly marked Public (see
/// CreateMemoryScreen and MemoriesRepository.fetchPublicMemories) — a real,
/// separate concept from "your circles", not a recap of your own circle
/// activity. A memory only ever ends up here if its uploader chose Public.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  // Set only on a genuine fetch failure — never for a successful query
  // that simply returned zero public memories. Those two cases render
  // completely different UI (see build()).
  bool _loadFailed = false;

  List<Memory> _publicMemories = [];
  List<Memory> _onThisDay = [];

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
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final memories = await MemoriesRepository.fetchPublicMemories();

      final now = DateTime.now();
      final onThisDay = memories.where((m) {
        return m.createdAt.month == now.month &&
            m.createdAt.day == now.day &&
            m.createdAt.year != now.year;
      }).toList();

      if (!mounted) return;
      setState(() {
        _publicMemories = memories;
        _onThisDay = onThisDay;
        _isLoading = false;
      });
    } catch (e, st) {
      // A genuine failure (network/query/RLS) — logged so the real cause
      // is visible in device logs, and surfaced as an actual error rather
      // than the empty-state message below (those two must never be
      // conflated: zero results is not a failure).
      debugPrint('DiscoverScreen: fetchPublicMemories failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  void _openMemory(Memory m) {
    final item = MemoryItem(
      id: m.id,
      title: m.caption?.isNotEmpty == true ? m.caption! : 'A shared memory',
      date: '${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}',
      imageUrl: m.imageUrl,
      semanticLabel: 'Shared memory photo',
      circle: 'Public',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
      type: MemoryType.photo,
    );
    context.push(AppRoutes.memoryDetailScreen, extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

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
                  SliverToBoxAdapter(child: SizedBox(height: topPadding + 12)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Discover',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  if (_loadFailed)
                    // Case B: an actual failure — shown, not hidden.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 60,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                "Couldn't load Discover right now.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _load,
                                child: Text(
                                  'Try again',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_publicMemories.isEmpty)
                    // Case A: the query succeeded — there simply are no
                    // public memories yet. Not an error.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 60,
                        ),
                        child: Center(
                          child: Text(
                            "Add a few public memories to your circle and "
                            "they'll start showing up here.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // ── On This Day ─────────────────────────────────────
                    if (_onThisDay.isNotEmpty) ...[
                      const _SectionHeader(title: 'On This Day', emoji: '✨'),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _onThisDay.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final m = _onThisDay[i];
                              return _OnThisDayCard(
                                memory: m,
                                onTap: () => _openMemory(m),
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],

                    // ── Public memories grid ────────────────────────────
                    const _SectionHeader(title: 'Public Memories', emoji: '🌍'),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final m = _publicMemories[i];
                          return _GridPhoto(
                            memory: m,
                            onTap: () => _openMemory(m),
                          );
                        }, childCount: _publicMemories.length),
                      ),
                    ),
                  ],

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

// ── Section header ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;

  const _SectionHeader({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── On This Day card ─────────────────────────────────────────────────────

class _OnThisDayCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const _OnThisDayCard({required this.memory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final yearsAgo = DateTime.now().year - memory.createdAt.year;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: memory.imageUrl,
              width: 150,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 150,
                height: 200,
                color: AppTheme.surfaceVariantDark,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 150,
                height: 200,
                color: AppTheme.surfaceVariantDark,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(190)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid photo tile ───────────────────────────────────────────────────────

class _GridPhoto extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const _GridPhoto({required this.memory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: memory.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppTheme.surfaceVariantDark),
        errorWidget: (_, __, ___) => Container(
          color: AppTheme.surfaceVariantDark,
          child: const Icon(
            Icons.image_not_supported_rounded,
            size: 18,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
