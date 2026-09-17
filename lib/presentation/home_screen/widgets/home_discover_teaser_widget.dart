import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/memories_repository.dart';

/// A small preview of public memories, linking into the full Discover screen.
///
/// Public memories intentionally have no circle-name/tag/count embossed on
/// the card. Circle names are reserved for private circle memories.
class _ExperiencePreview {
  final String memoryId;
  final String coverImageUrl;

  const _ExperiencePreview({
    required this.memoryId,
    required this.coverImageUrl,
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
      final memories = await MemoriesRepository.fetchPublicMemories();
      final experiences = [
        for (final m in memories.take(2))
          _ExperiencePreview(
            memoryId: m.id,
            coverImageUrl: m.imageUrl,
          ),
      ];

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
        context.go(AppRoutes.discoverScreen);
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
