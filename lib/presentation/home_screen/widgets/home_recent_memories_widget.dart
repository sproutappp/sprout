import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/memories_repository.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../widgets/status_badge_widget.dart';
import '../../memories_screen/widgets/memories_grid_widget.dart' hide MemoryPrivacy;

class _MemoryCard {
  final String id, title, date, imageUrl, semanticLabel, circle;
  final Color circleColor;
  final MemoryPrivacy privacy;
  final int reactionCount, commentCount;

  const _MemoryCard({
    required this.id,
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

  static const _palette = [
    Color(0xFF39FF8C),
    Color(0xFFFF8C39),
    Color(0xFF00E5FF),
    Color(0xFFB839FF),
  ];

  factory _MemoryCard.fromMemory(Memory m, int index) {
    return _MemoryCard(
      id: m.id,
      title: m.caption?.isNotEmpty == true ? m.caption! : 'A shared memory',
      date: m.createdAt.toIso8601String(),
      imageUrl: m.imageUrl,
      semanticLabel: 'Shared memory photo',
      circle: m.circleName ?? 'Circle',
      circleColor: _palette[index % _palette.length],
      // All memories are circle-scoped for now — there's no "public"
      // sharing concept in the schema yet.
      privacy: MemoryPrivacy.circle,
      // Reactions/comments aren't tracked yet — showing 0 rather than
      // a fake number.
      reactionCount: 0,
      commentCount: 0,
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
  List<_MemoryCard> _memories = [];
  bool _isLoading = true;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _load();
  }

  Future<void> _load() async {
    try {
      final memories = await MemoriesRepository.fetchAllForUser();
      if (!mounted) return;
      setState(() {
        _memories = [
          for (var i = 0; i < memories.length && i < 8; i++)
            _MemoryCard.fromMemory(memories[i], i),
        ];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryGreen,
              ),
            ),
          )
        else if (_memories.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isTablet ? 32 : 20,
            ),
            child: const Text(
              'No memories yet.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          )
        else
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
        final memory = MemoryItem(
          id: m.id,
          title: m.title,
          date: _formatFullDate(m.date),
          imageUrl: m.imageUrl,
          semanticLabel: m.semanticLabel,
          circle: m.circle,
          circleColor: m.circleColor,
          privacy: m.privacy,
          type: MemoryType.photo,
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

  String _formatFullDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}