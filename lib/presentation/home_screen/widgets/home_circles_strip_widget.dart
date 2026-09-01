import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../models/circle.dart';
import '../../../services/circles_repository.dart';

class _CircleModel {
  final String id, name, recentActivity, avatarUrl, semanticLabel;
  final int memberCount;
  final Color color;

  const _CircleModel({
    required this.id,
    required this.name,
    required this.recentActivity,
    required this.avatarUrl,
    required this.semanticLabel,
    required this.memberCount,
    required this.color,
  });

  static const _palette = [
    Color(0xFFFF8C39),
    Color(0xFF00E5FF),
    Color(0xFF39FF8C),
    Color(0xFFB839FF),
  ];

  factory _CircleModel.fromCircle(Circle circle, int index) => _CircleModel(
    id: circle.id,
    name: circle.name,
    recentActivity:
        '${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'}',
    avatarUrl: circle.coverImageUrl ??
        'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=200',
    semanticLabel: '${circle.name} circle cover photo',
    memberCount: circle.memberCount,
    color: _palette[index % _palette.length],
  );
}

class HomeCirclesStripWidget extends StatefulWidget {
  const HomeCirclesStripWidget({super.key});

  @override
  State<HomeCirclesStripWidget> createState() => _HomeCirclesStripWidgetState();
}

class _HomeCirclesStripWidgetState extends State<HomeCirclesStripWidget> {
  List<_CircleModel> _circles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() {
        // Home strip shows a quick top few, not the full list.
        _circles = [
          for (var i = 0; i < circles.length && i < 4; i++)
            _CircleModel.fromCircle(circles[i], i),
        ];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryGreen,
              ),
            ),
          )
        else if (_circles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No circles yet.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          )
        else
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
          border: Border.all(color: AppTheme.outline, width: 0.8),
        ),
        child: Row(
          children: [
            // Circle avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.outline, width: 1.0),
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
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w400,
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
