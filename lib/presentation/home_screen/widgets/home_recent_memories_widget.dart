import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../widgets/status_badge_widget.dart';
import '../../memories_screen/widgets/memories_grid_widget.dart' hide MemoryPrivacy;

// ── Map-first mock data aligned with allMemories ids ─────────────────────────
final List<Map<String, dynamic>> _recentMemoryMaps = [
  {
    'id': 'mem_001',
    'memoryId': 'm01',
    'title': 'Sunrise hike at Mullayanagiri',
    'date': '2026-08-26',
    'imageUrl': 'https://images.unsplash.com/photo-1598464703239-a0b246133231',
    'semanticLabel':
        'Golden sunrise light breaking over misty mountain peaks, hikers silhouetted in foreground',
    'circle': 'Adventure Crew',
    'circleColor': 0xFF39FF8C,
    'privacy': 'circle',
    'reactionCount': 12,
    'commentCount': 4,
  },
  {
    'id': 'mem_002',
    'memoryId': 'm02',
    'title': 'Grandma\'s 80th birthday',
    'date': '2026-08-22',
    'imageUrl':
        'https://images.pexels.com/photos/1729931/pexels-photo-1729931.jpeg?w=600',
    'semanticLabel':
        'Elderly woman blowing out candles on a decorated birthday cake surrounded by family',
    'circle': 'Family',
    'circleColor': 0xFFFF8C39,
    'privacy': 'circle',
    'reactionCount': 28,
    'commentCount': 11,
  },
  {
    'id': 'mem_003',
    'memoryId': 'm03',
    'title': 'Late night chai at Irani Café',
    'date': '2026-08-20',
    'imageUrl':
        'https://img.rocket.new/generatedImages/rocket_gen_img_1fc8f9897-1784582440087.png',
    'semanticLabel':
        'Two ceramic cups of chai on a wooden café table with warm ambient lighting',
    'circle': 'College Friends',
    'circleColor': 0xFF00E5FF,
    'privacy': 'public',
    'reactionCount': 7,
    'commentCount': 2,
  },
  {
    'id': 'mem_004',
    'memoryId': 'm04',
    'title': 'Monsoon drive to Coorg',
    'date': '2026-08-15',
    'imageUrl': 'https://images.unsplash.com/photo-1527703345282-8d097cb9a05f',
    'semanticLabel':
        'Winding road through dense green coffee plantations in heavy monsoon rain',
    'circle': 'Best Friends',
    'circleColor': 0xFFB839FF,
    'privacy': 'circle',
    'reactionCount': 19,
    'commentCount': 6,
  },
];

class _MemoryCard {
  final String id, memoryId, title, date, imageUrl, semanticLabel, circle;
  final Color circleColor;
  final MemoryPrivacy privacy;
  final int reactionCount, commentCount;

  const _MemoryCard({
    required this.id,
    required this.memoryId,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.semanticLabel,
    required this.circle,
    required this.circleColor,
    required this.privacy,
    required this.reactionCount,
    required this.commentCount,
  });

  static MemoryPrivacy _privacyFromString(String v) {
    switch (v) {
      case 'public':
        return MemoryPrivacy.public;
      case 'circle':
        return MemoryPrivacy.circle;
      default:
        return MemoryPrivacy.private;
    }
  }

  factory _MemoryCard.fromMap(Map<String, dynamic> map) {
    return _MemoryCard(
      id: map['id'] as String,
      memoryId: map['memoryId'] as String,
      title: map['title'] as String,
      date: map['date'] as String,
      imageUrl: map['imageUrl'] as String,
      semanticLabel: map['semanticLabel'] as String,
      circle: map['circle'] as String,
      circleColor: Color(map['circleColor'] as int),
      privacy: _privacyFromString(map['privacy'] as String),
      reactionCount: map['reactionCount'] as int,
      commentCount: map['commentCount'] as int,
    );
  }
}

class HomeRecentMemoriesWidget extends StatefulWidget {
  final bool isTablet;
  const HomeRecentMemoriesWidget({super.key, required this.isTablet});

  @override
  State<HomeRecentMemoriesWidget> createState() =>
      _HomeRecentMemoriesWidgetState();
}

class _HomeRecentMemoriesWidgetState extends State<HomeRecentMemoriesWidget>
    with SingleTickerProviderStateMixin {
  late List<_MemoryCard> _memories;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _memories = _recentMemoryMaps.map(_MemoryCard.fromMap).toList();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.isTablet ? 32 : 20),
          child: Row(
            children: [
              const Text(
                'Your Memories',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(AppRoutes.memoriesScreen),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isTablet ? 32 : 20,
            ),
            itemCount: _memories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final delay = index * 80;
              final anim = CurvedAnimation(
                parent: _entranceController,
                curve: Interval(
                  (delay / 600).clamp(0.0, 1.0),
                  ((delay + 400) / 600).clamp(0.0, 1.0),
                  curve: Curves.easeOutCubic,
                ),
              );
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: _MemoryCardWidget(memory: _memories[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemoryCardWidget extends StatefulWidget {
  final _MemoryCard memory;
  const _MemoryCardWidget({required this.memory});

  @override
  State<_MemoryCardWidget> createState() => _MemoryCardWidgetState();
}

class _MemoryCardWidgetState extends State<_MemoryCardWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.memory;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        final memory = allMemories.firstWhere(
          (item) => item.id == m.memoryId,
          orElse: () => allMemories[0],
        );
        context.push(AppRoutes.memoryDetailScreen, extra: memory);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo
                CachedNetworkImage(
                  imageUrl: m.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const LoadingSkeletonWidget(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surfaceVariantDark,
                    child: const Icon(
                      Icons.photo_outlined,
                      color: AppTheme.textMuted,
                      size: 32,
                    ),
                  ),
                ),

                // Gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardOverlayGradient,
                  ),
                ),

                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Circle tag
                        CircleTagWidget(name: m.circle, color: m.circleColor),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          m.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Date + reactions
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 10,
                              color: Colors.white.withAlpha(153),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(m.date),
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                color: Colors.white.withAlpha(153),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.favorite_rounded,
                              size: 11,
                              color: Colors.white.withAlpha(179),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${m.reactionCount}',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                color: Colors.white.withAlpha(179),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Privacy badge top-right
                Positioned(
                  top: 10,
                  right: 10,
                  child: PrivacyBadgeWidget(privacy: m.privacy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}