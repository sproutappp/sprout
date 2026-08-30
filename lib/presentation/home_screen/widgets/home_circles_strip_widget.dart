import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';

final List<Map<String, dynamic>> _circleMaps = [
  {
    'id': 'c_001',
    'name': 'Family',
    'memberCount': 8,
    'recentActivity': '2 new memories',
    'avatarUrl':
        'https://img.rocket.new/generatedImages/rocket_gen_img_1d2bed938-1765283409039.png',
    'semanticLabel': 'Family circle — group of people laughing together',
    'color': 0xFFFF8C39,
    'hasActivity': true,
  },
  {
    'id': 'c_002',
    'name': 'College Friends',
    'memberCount': 14,
    'recentActivity': '1 new memory',
    'avatarUrl': 'https://images.unsplash.com/photo-1645213130835-e75814155d6c',
    'semanticLabel': 'College friends circle — group of young people at campus',
    'color': 0xFF00E5FF,
    'hasActivity': true,
  },
  {
    'id': 'c_003',
    'name': 'Adventure Crew',
    'memberCount': 5,
    'recentActivity': 'Active today',
    'avatarUrl':
        'https://img.rocket.new/generatedImages/rocket_gen_img_1749221e8-1787940376962.png',
    'semanticLabel': 'Adventure crew circle — hikers on mountain trail',
    'color': 0xFF39FF8C,
    'hasActivity': true,
  },
  {
    'id': 'c_004',
    'name': 'Best Friends',
    'memberCount': 4,
    'recentActivity': '3 days ago',
    'avatarUrl': 'https://images.unsplash.com/photo-1695234370339-8e4f785fad7b',
    'semanticLabel': 'Best friends circle — close group of friends smiling',
    'color': 0xFFB839FF,
    'hasActivity': false,
  },
];

class _CircleModel {
  final String id, name, recentActivity, avatarUrl, semanticLabel;
  final int memberCount;
  final Color color;
  final bool hasActivity;

  const _CircleModel({
    required this.id,
    required this.name,
    required this.recentActivity,
    required this.avatarUrl,
    required this.semanticLabel,
    required this.memberCount,
    required this.color,
    required this.hasActivity,
  });

  factory _CircleModel.fromMap(Map<String, dynamic> map) => _CircleModel(
    id: map['id'] as String,
    name: map['name'] as String,
    recentActivity: map['recentActivity'] as String,
    avatarUrl: map['avatarUrl'] as String,
    semanticLabel: map['semanticLabel'] as String,
    memberCount: map['memberCount'] as int,
    color: Color(map['color'] as int),
    hasActivity: map['hasActivity'] as bool,
  );
}

class HomeCirclesStripWidget extends StatefulWidget {
  const HomeCirclesStripWidget({super.key});

  @override
  State<HomeCirclesStripWidget> createState() => _HomeCirclesStripWidgetState();
}

class _HomeCirclesStripWidgetState extends State<HomeCirclesStripWidget> {
  List<_CircleModel> _circles = [];

  @override
  void initState() {
    super.initState();
    _circles = _circleMaps.map(_CircleModel.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Your Circles',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.circlesScreen),
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
        const SizedBox(height: 14),
        Column(
          children: _circles.map((circle) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CircleRowItem(circle: circle),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CircleRowItem extends StatefulWidget {
  final _CircleModel circle;
  const _CircleRowItem({required this.circle});

  @override
  State<_CircleRowItem> createState() => _CircleRowItemState();
}

class _CircleRowItemState extends State<_CircleRowItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.circle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => context.push(AppRoutes.circleDetailScreen, extra: c.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed ? AppTheme.surfaceElevatedDark : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.hasActivity ? c.color.withAlpha(64) : AppTheme.outline,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // Circle avatar with activity ring
            Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.hasActivity
                          ? c.color.withAlpha(153)
                          : AppTheme.outline,
                      width: c.hasActivity ? 2.0 : 1.0,
                    ),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: c.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppTheme.surfaceVariantDark),
                      errorWidget: (_, __, ___) => Container(
                        color: c.color.withAlpha(38),
                        child: Icon(
                          Icons.group_rounded,
                          size: 20,
                          color: c.color,
                        ),
                      ),
                    ),
                  ),
                ),
                if (c.hasActivity)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.surfaceDark,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // Name + activity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 11,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${c.memberCount} members',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppTheme.textDisabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.recentActivity,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: c.hasActivity ? c.color : AppTheme.textMuted,
                          fontWeight: c.hasActivity
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
