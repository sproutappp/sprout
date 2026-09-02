import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/circles_repository.dart';
import '../../../services/memories_repository.dart';

/// A small preview of "Your Experiences" (circles with memories in them),
/// linking into the full Discover screen. Replaces an earlier version that
/// showed fake public content ("From the World") from the old public-feed
/// concept — there's no such feature in this app anymore.
class _ExperiencePreview {
  final String circleId;
  final String circleName;
  final String coverImageUrl;
  final int memoryCount;

  const _ExperiencePreview({
    required this.circleId,
    required this.circleName,
    required this.coverImageUrl,
    required this.memoryCount,
  });
}

class HomeDiscoverTeaserWidget extends StatefulWidget {
  final bool isTablet;
  const HomeDiscoverTeaserWidget({super.key, required this.isTablet});

  @override
  State<HomeDiscoverTeaserWidget> createState() =>
      _HomeDiscoverTeaserWidgetState();
}

class _HomeDiscoverTeaserWidgetState extends State<HomeDiscoverTeaserWidget> {
  List<_ExperiencePreview> _experiences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      final memories = await MemoriesRepository.fetchAllForUser();

      final byCircle = <String, int>{};
      final coverByCircle = <String, String>{};
      for (final m in memories) {
        byCircle[m.circleId] = (byCircle[m.circleId] ?? 0) + 1;
        coverByCircle.putIfAbsent(m.circleId, () => m.imageUrl);
      }

      final experiences = [
        for (final c in circles)
          if (byCircle.containsKey(c.id))
            _ExperiencePreview(
              circleId: c.id,
              circleName: c.name,
              coverImageUrl: coverByCircle[c.id]!,
              memoryCount: byCircle[c.id]!,
            ),
      ];
      // Show at most 2 here — it's a teaser, not the full list.
      experiences.length = experiences.length > 2 ? 2 : experiences.length;

      if (!mounted) return;
      setState(() {
        _experiences = experiences;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _experiences.isEmpty) {
      // Nothing to preview yet — don't show an empty/broken-looking section.
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Discover',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
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
        if (_isLoading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryGreen,
            ),
          )
        else if (widget.isTablet)
          Row(
            children: _experiences.map((e) {
              final isLast = e == _experiences.last;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12),
                  child: _ExperiencePreviewCard(experience: e),
                ),
              );
            }).toList(),
          )
        else
          Column(
            children: _experiences.map((e) {
              final isLast = e == _experiences.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: _ExperiencePreviewCard(experience: e),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _ExperiencePreviewCard extends StatefulWidget {
  final _ExperiencePreview experience;
  const _ExperiencePreviewCard({required this.experience});

  @override
  State<_ExperiencePreviewCard> createState() =>
      _ExperiencePreviewCardState();
}

class _ExperiencePreviewCardState extends State<_ExperiencePreviewCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.experience;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        context.push(AppRoutes.circleDetailScreen, extra: e.circleId);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outline, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: e.coverImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppTheme.surfaceVariantDark),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surfaceVariantDark,
                    child: const Icon(
                      Icons.photo_outlined,
                      color: AppTheme.textMuted,
                      size: 40,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xE60A0F0D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.circleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.memoryCount} ${e.memoryCount == 1 ? 'memory' : 'memories'}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: Colors.white.withAlpha(179),
                          fontWeight: FontWeight.w500,
                        ),
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
