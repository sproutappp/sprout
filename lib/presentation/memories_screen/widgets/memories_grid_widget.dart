import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';

enum MemoryPrivacy { public, circle, private }
enum MemoryType { photo }

String memoryDisplayTitle(String? caption) {
  final value = (caption ?? '').trim();
  if (value.isEmpty) return 'A memory';
  final separator = value.indexOf(' — ');
  return separator > 0 ? value.substring(0, separator).trim() : value;
}

class MemoryItem {
  final String id;
  final String _rawTitle;
  final String date;
  final String imageUrl;
  final String semanticLabel;
  final String circle;
  final Color circleColor;
  final MemoryPrivacy privacy;
  final MemoryType type;

  String get title => memoryDisplayTitle(_rawTitle);

  const MemoryItem({
    required this.id,
    required String title,
    required this.date,
    required this.imageUrl,
    required this.semanticLabel,
    required this.circle,
    required this.circleColor,
    required this.privacy,
    required this.type,
  }) : _rawTitle = title;
}

Map<String, List<MemoryItem>> groupMemoriesByMonth(List<MemoryItem> memories) {
  final grouped = <String, List<MemoryItem>>{};
  for (final memory in memories) {
    final parts = memory.date.split(' ');
    final key = parts.length >= 3 ? '${parts[0]} ${parts[2]}' : memory.date;
    grouped.putIfAbsent(key, () => []).add(memory);
  }
  return grouped;
}

class MemoriesGridWidget extends StatelessWidget {
  final List<MemoryItem> memories;
  final ValueChanged<String>? onDeleted;

  const MemoriesGridWidget({
    super.key,
    required this.memories,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) return const _EmptyMemories();

    final grouped = groupMemoriesByMonth(memories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries
          .map((entry) => _MonthSection(
                monthLabel: entry.key,
                memories: entry.value,
                onDeleted: onDeleted,
              ))
          .toList(),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final String monthLabel;
  final List<MemoryItem> memories;
  final ValueChanged<String>? onDeleted;

  const _MonthSection({
    required this.monthLabel,
    required this.memories,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
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
        ...memories.map(
          (memory) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemoryHorizontalCard(
              memory: memory,
              onDeleted: onDeleted,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MemoryHorizontalCard extends StatefulWidget {
  final MemoryItem memory;
  final ValueChanged<String>? onDeleted;

  const _MemoryHorizontalCard({
    required this.memory,
    this.onDeleted,
  });

  @override
  State<_MemoryHorizontalCard> createState() => _MemoryHorizontalCardState();
}

class _MemoryHorizontalCardState extends State<_MemoryHorizontalCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final memory = widget.memory;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () async {
        final deleted = await context.push<bool>(
          '/memory-detail-screen',
          extra: memory,
        );
        if (deleted == true) {
          widget.onDeleted?.call(memory.id);
        }
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
              SizedBox(
                width: 96,
                height: 96,
                child: CachedNetworkImage(
                  imageUrl: memory.imageUrl,
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
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        memory.title,
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
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: AppTheme.textDisabled,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            memory.date,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: memory.circleColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    memory.circle,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: memory.circleColor.withAlpha(210),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PrivacyPill(privacy: memory.privacy),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
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

class _PrivacyPill extends StatelessWidget {
  final MemoryPrivacy privacy;

  const _PrivacyPill({required this.privacy});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String label;

    switch (privacy) {
      case MemoryPrivacy.public:
        icon = Icons.public_rounded;
        color = AppTheme.cyanAccent;
        label = 'Public';
      case MemoryPrivacy.circle:
        icon = Icons.group_rounded;
        color = AppTheme.primaryGreen;
        label = 'Circle';
      case MemoryPrivacy.private:
        icon = Icons.lock_rounded;
        color = AppTheme.textMuted;
        label = 'Private';
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
