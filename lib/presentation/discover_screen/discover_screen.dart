import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/memory.dart';
import '../../services/circles_repository.dart';
import '../../services/memories_repository.dart';
import '../memories_screen/widgets/memories_grid_widget.dart' show MemoryItem, MemoryPrivacy, MemoryType;

// ── View-models ──────────────────────────────────────────────────────────
// Discover is built entirely from circles + memories the user already has
// real access to (both queries are RLS-scoped server-side) — no new tables,
// no public/private concept, nothing invented.

class _Experience {
  final String circleId;
  final String circleName;
  final String coverImageUrl;
  final int memoryCount;

  const _Experience({
    required this.circleId,
    required this.circleName,
    required this.coverImageUrl,
    required this.memoryCount,
  });
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  String? _error;

  List<Memory> _allMemories = [];
  List<_Experience> _experiences = [];
  List<Memory> _onThisDay = [];
  String? _selectedCircleFilter; // null = All

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      final memories = await MemoriesRepository.fetchAllForUser();

      // Group memories by circle to build cover + count for each experience,
      // and to find "on this day" matches — all client-side, no extra calls.
      final byCircle = <String, List<Memory>>{};
      for (final m in memories) {
        byCircle.putIfAbsent(m.circleId, () => []).add(m);
      }

      final now = DateTime.now();
      final onThisDay = memories.where((m) {
        return m.createdAt.month == now.month &&
            m.createdAt.day == now.day &&
            m.createdAt.year != now.year;
      }).toList();

      final experiences = <_Experience>[];
      for (final circle in circles) {
        final circleMemories = byCircle[circle.id];
        if (circleMemories == null || circleMemories.isEmpty) {
          continue; // nothing to rediscover in an empty circle yet
        }
        experiences.add(
          _Experience(
            circleId: circle.id,
            circleName: circle.name,
            coverImageUrl: circleMemories.first.imageUrl, // already most-recent-first
            memoryCount: circleMemories.length,
          ),
        );
      }
      // Most recently active circle first.
      experiences.sort((a, b) {
        final aLatest = byCircle[a.circleId]!.first.createdAt;
        final bLatest = byCircle[b.circleId]!.first.createdAt;
        return bLatest.compareTo(aLatest);
      });

      if (!mounted) return;
      setState(() {
        _allMemories = memories;
        _experiences = experiences;
        _onThisDay = onThisDay;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load Discover right now.";
        _isLoading = false;
      });
    }
  }

  List<Memory> get _filteredRecent {
    if (_selectedCircleFilter == null) return _allMemories;
    return _allMemories
        .where((m) => m.circleId == _selectedCircleFilter)
        .toList();
  }

  void _openMemory(Memory m) {
    final item = MemoryItem(
      id: m.id,
      title: m.caption?.isNotEmpty == true ? m.caption! : 'A shared memory',
      date: '${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}',
      imageUrl: m.imageUrl,
      semanticLabel: 'Shared memory photo',
      circle: m.circleName ?? 'Circle',
      circleColor: AppTheme.primaryGreen,
      privacy: MemoryPrivacy.circle,
      type: MemoryType.photo,
    );
    context.push(AppRoutes.memoryDetailScreen, extra: item);
  }

  void _openExperience(_Experience e) {
    context.push(AppRoutes.circleDetailScreen, extra: e.circleId);
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
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: GoogleFonts.manrope(color: AppTheme.textMuted),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Revisit the moments you\'ve already shared',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),

                  if (_experiences.isEmpty && _allMemories.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 60,
                        ),
                        child: Center(
                          child: Text(
                            'Add a few memories to your circles and they\'ll '
                            'start showing up here to rediscover.',
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
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
                    ],

                    // ── Your Experiences ────────────────────────────────
                    if (_experiences.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      const _SectionHeader(title: 'Your Experiences', emoji: '🌿'),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final e = _experiences[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ExperienceCard(
                                experience: e,
                                onTap: () => _openExperience(e),
                              ),
                            );
                          }, childCount: _experiences.length),
                        ),
                      ),
                    ],

                    // ── Recent memories, filterable by circle ───────────
                    if (_allMemories.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      const _SectionHeader(title: 'Recent Memories', emoji: '📸'),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              _FilterChip(
                                label: 'All',
                                selected: _selectedCircleFilter == null,
                                onTap: () =>
                                    setState(() => _selectedCircleFilter = null),
                              ),
                              const SizedBox(width: 8),
                              for (final e in _experiences) ...[
                                _FilterChip(
                                  label: e.circleName,
                                  selected: _selectedCircleFilter == e.circleId,
                                  onTap: () => setState(
                                    () => _selectedCircleFilter = e.circleId,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),
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
                            final m = _filteredRecent[i];
                            return _GridPhoto(
                              memory: m,
                              onTap: () => _openMemory(m),
                            );
                          }, childCount: _filteredRecent.length),
                        ),
                      ),
                    ],
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

// ── Experience card (a circle, rendered as a revisitable collection) ─────

class _ExperienceCard extends StatelessWidget {
  final _Experience experience;
  final VoidCallback onTap;

  const _ExperienceCard({required this.experience, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: experience.coverImageUrl,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 160,
                color: AppTheme.surfaceVariantDark,
              ),
              errorWidget: (_, __, ___) => Container(
                height: 160,
                color: AppTheme.surfaceVariantDark,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(210)],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          experience.circleName,
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${experience.memoryCount} '
                          '${experience.memoryCount == 1 ? 'memory' : 'memories'}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
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

// ── Filter chip ───────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : AppTheme.outline,
            width: 0.8,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : AppTheme.textMuted,
            ),
          ),
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
