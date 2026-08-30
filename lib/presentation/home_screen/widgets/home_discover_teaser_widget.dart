import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../memories_screen/widgets/memories_grid_widget.dart';

final List<Map<String, dynamic>> _discoverMaps = [
  {
    'id': 'd_001',
    'memoryId': 'm01',
    'title': 'Cherry blossoms in full bloom',
    'location': 'Shinjuku Gyoen, Tokyo',
    'creator': 'Aiko Tanaka',
    'imageUrl': 'https://images.unsplash.com/photo-1617290958007-8aacaa047d12',
    'semanticLabel':
        'Rows of pale pink cherry blossom trees in full bloom against a bright blue sky in a Japanese garden',
    'reactionCount': 341,
    'timeAgo': '2h ago',
  },
  {
    'id': 'd_002',
    'memoryId': 'm03',
    'title': 'Street food evening in Oaxaca',
    'location': 'Oaxaca, Mexico',
    'creator': 'Carlos Mendez',
    'imageUrl': 'https://images.unsplash.com/photo-1717778446442-3df92a7d54c8',
    'semanticLabel':
        'Colorful street food stalls lit by warm lanterns at dusk in a cobblestone Mexican town square',
    'reactionCount': 188,
    'timeAgo': '5h ago',
  },
];

class _DiscoverCard {
  final String id,
      memoryId,
      title,
      location,
      creator,
      imageUrl,
      semanticLabel,
      timeAgo;
  final int reactionCount;

  const _DiscoverCard({
    required this.id,
    required this.memoryId,
    required this.title,
    required this.location,
    required this.creator,
    required this.imageUrl,
    required this.semanticLabel,
    required this.timeAgo,
    required this.reactionCount,
  });

  factory _DiscoverCard.fromMap(Map<String, dynamic> map) => _DiscoverCard(
    id: map['id'] as String,
    memoryId: map['memoryId'] as String,
    title: map['title'] as String,
    location: map['location'] as String,
    creator: map['creator'] as String,
    imageUrl: map['imageUrl'] as String,
    semanticLabel: map['semanticLabel'] as String,
    timeAgo: map['timeAgo'] as String,
    reactionCount: map['reactionCount'] as int,
  );
}

class HomeDiscoverTeaserWidget extends StatefulWidget {
  final bool isTablet;
  const HomeDiscoverTeaserWidget({super.key, required this.isTablet});

  @override
  State<HomeDiscoverTeaserWidget> createState() =>
      _HomeDiscoverTeaserWidgetState();
}

class _HomeDiscoverTeaserWidgetState extends State<HomeDiscoverTeaserWidget> {
  late List<_DiscoverCard> _cards;

  @override
  void initState() {
    super.initState();
    _cards = _discoverMaps.map(_DiscoverCard.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                'From the World',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenGlow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.discoverScreen),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Explore',
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
        const SizedBox(height: 14),
        if (widget.isTablet)
          Row(
            children: _cards.map((card) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: card == _cards.last ? 0 : 12),
                  child: _DiscoverCardWidget(card: card),
                ),
              );
            }).toList(),
          )
        else
          Column(
            children: _cards.map((card) {
              return Padding(
                padding: EdgeInsets.only(bottom: card == _cards.last ? 0 : 12),
                child: _DiscoverCardWidget(card: card),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _DiscoverCardWidget extends StatefulWidget {
  final _DiscoverCard card;
  const _DiscoverCardWidget({required this.card});

  @override
  State<_DiscoverCardWidget> createState() => _DiscoverCardWidgetState();
}

class _DiscoverCardWidgetState extends State<_DiscoverCardWidget> {
  bool _pressed = false;
  bool _reacted = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        final memory = allMemories.firstWhere(
          (m) => m.id == c.memoryId,
          orElse: () => allMemories[0],
        );
        context.push(AppRoutes.memoryDetailScreen, extra: memory);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                CachedNetworkImage(
                  imageUrl: c.imageUrl,
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
                      size: 40,
                    ),
                  ),
                ),

                // Gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xE60A0F0D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 1.0],
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Creator row top
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(115),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 11,
                                  color: Colors.white.withAlpha(204),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.creator,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withAlpha(230),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(115),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c.timeAgo,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                color: Colors.white.withAlpha(179),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Title
                      Text(
                        c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Location + reactions row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Colors.white.withAlpha(153),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              c.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                color: Colors.white.withAlpha(153),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Reaction button
                          GestureDetector(
                            onTap: () => setState(() => _reacted = !_reacted),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _reacted
                                    ? AppTheme.primaryGreen.withAlpha(51)
                                    : Colors.black.withAlpha(102),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _reacted
                                      ? AppTheme.primaryGreen.withAlpha(102)
                                      : Colors.white.withAlpha(38),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _reacted
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 13,
                                    color: _reacted
                                        ? AppTheme.primaryGreen
                                        : Colors.white.withAlpha(204),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${c.reactionCount + (_reacted ? 1 : 0)}',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _reacted
                                          ? AppTheme.primaryGreen
                                          : Colors.white.withAlpha(204),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
