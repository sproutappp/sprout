import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';

// ── Mock Data ─────────────────────────────────────────────────────────────────

enum MemoryPrivacy { public, circle, private }

enum MemoryType { photo, video, story }

class MemoryItem {
  final String id;
  final String title;
  final String date;
  final String imageUrl;
  final String semanticLabel;
  final String circle;
  final Color circleColor;
  final MemoryPrivacy privacy;
  final MemoryType type;

  const MemoryItem({
    required this.id,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.semanticLabel,
    required this.circle,
    required this.circleColor,
    required this.privacy,
    required this.type,
  });
}

// ── Legacy mock data ─────────────────────────────────────────────────────
// Still used by home_recent_memories_widget, home_discover_teaser_widget,
// and notifications_screen — those aren't wired to real Supabase data yet.
// The real feed (MemoriesScreen) no longer uses this.
final List<MemoryItem> allMemories = [
  MemoryItem(
    id: 'm01',
    title: 'Sunrise at Mullayanagiri',
    date: 'Aug 26, 2026',
    imageUrl:
        'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=600',
    semanticLabel:
        'Golden sunrise breaking over misty mountain peaks with silhouetted trees',
    circle: 'Adventure Crew',
    circleColor: AppTheme.primaryGreen,
    privacy: MemoryPrivacy.circle,
    type: MemoryType.photo,
  ),
  MemoryItem(
    id: 'm02',
    title: 'Grandma\'s 80th birthday',
    date: 'Aug 22, 2026',
    imageUrl:
        'https://images.pexels.com/photos/1729931/pexels-photo-1729931.jpeg?w=600',
    semanticLabel:
        'Elderly woman smiling warmly surrounded by family at birthday celebration',
    circle: 'Family',
    circleColor: const Color(0xFFFFB84D),
    privacy: MemoryPrivacy.circle,
    type: MemoryType.photo,
  ),
  MemoryItem(
    id: 'm03',
    title: 'Late night café talks',
    date: 'Aug 10, 2026',
    imageUrl:
        'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?w=600',
    semanticLabel: 'Friends gathered around a table at a dimly lit café',
    circle: 'College Friends',
    circleColor: AppTheme.cyanAccent,
    privacy: MemoryPrivacy.circle,
    type: MemoryType.photo,
  ),
];

// Group memories by month — preserving insertion order
Map<String, List<MemoryItem>> groupMemoriesByMonth(List<MemoryItem> memories) {
  final Map<String, List<MemoryItem>> grouped = {};
  for (final m in memories) {
    final parts = m.date.split(' ');
    final key = '${parts[0]} ${parts[2]}';
    grouped.putIfAbsent(key, () => []).add(m);
  }
  return grouped;
}

// ── List Widget ───────────────────────────────────────────────────────────────

class MemoriesGridWidget extends StatelessWidget {
  final List<MemoryItem> memories;

  const MemoriesGridWidget({super.key, required this.memories});

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return const _EmptyMemories();
    }

    final grouped = groupMemoriesByMonth(memories);
    final sections = grouped.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((entry) {
        return _MonthSection(monthLabel: entry.key, memories: entry.value);
      }).toList(),
    );
  }
}

// ── Month Section ─────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final String monthLabel;
  final List<MemoryItem> memories;

  const _MonthSection({required this.monthLabel, required this.memories});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month separator
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              // Accent dot
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                monthLabel.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreenGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${memories.length}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal memory list
        ...memories.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemoryHorizontalCard(memory: m),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Horizontal Memory Card ────────────────────────────────────────────────────

class _MemoryHorizontalCard extends StatefulWidget {
  final MemoryItem memory;

  const _MemoryHorizontalCard({required this.memory});

  @override
  State<_MemoryHorizontalCard> createState() => _MemoryHorizontalCardState();
}

class _MemoryHorizontalCardState extends State<_MemoryHorizontalCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.memory;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        context.push('/memory-detail-screen', extra: m);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // ── Thumbnail ──────────────────────────────────────────────────
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: m.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppTheme.surfaceVariantDark),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.textDisabled,
                          size: 24,
                        ),
                      ),
                    ),

                    // Subtle right-edge fade for seamless blend into card body
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              AppTheme.cardDark.withAlpha(180),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Type badge (video / story)
                    if (m.type != MemoryType.photo)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(170),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                m.type == MemoryType.video
                                    ? Icons.play_circle_filled_rounded
                                    : Icons.auto_stories_rounded,
                                size: 9,
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                m.type == MemoryType.video ? 'Video' : 'Story',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      Text(
                        m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),

                      // Date row
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: AppTheme.textDisabled,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m.date,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),

                      // Bottom row: circle + indicators
                      Row(
                        children: [
                          // Circle chip
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: m.circleColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: m.circleColor.withAlpha(100),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    m.circle,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: m.circleColor.withAlpha(210),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Privacy indicator
                          _PrivacyPill(privacy: m.privacy),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Chevron ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Privacy Pill ──────────────────────────────────────────────────────────────

class _PrivacyPill extends StatelessWidget {
  final MemoryPrivacy privacy;

  const _PrivacyPill({required this.privacy});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (privacy) {
      case MemoryPrivacy.public:
        icon = Icons.public_rounded;
        color = AppTheme.cyanAccent;
        label = 'Public';
        break;
      case MemoryPrivacy.circle:
        icon = Icons.group_rounded;
        color = AppTheme.primaryGreen;
        label = 'Circle';
        break;
      case MemoryPrivacy.private:
        icon = Icons.lock_rounded;
        color = AppTheme.textMuted;
        label = 'Private';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyMemories extends StatelessWidget {
  const _EmptyMemories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenGlow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.photo_album_outlined,
                size: 32,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No memories yet',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Capture your first memory',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
