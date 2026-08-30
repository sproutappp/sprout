import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../memories_screen/widgets/memories_grid_widget.dart';

// ── Sample Public Memory Data ─────────────────────────────────────────────────

class _PublicMemory {
  final String id;
  final String title;
  final String caption;
  final String imageUrl;
  final String semanticLabel;
  final String creatorName;
  final String creatorAvatar;
  final String creatorAvatarLabel;
  final String location;
  final String timeAgo;
  final int reactions;
  final int comments;

  const _PublicMemory({
    required this.id,
    required this.title,
    required this.caption,
    required this.imageUrl,
    required this.semanticLabel,
    required this.creatorName,
    required this.creatorAvatar,
    required this.creatorAvatarLabel,
    required this.location,
    required this.timeAgo,
    required this.reactions,
    required this.comments,
  });
}

final List<_PublicMemory> _publicMemories = [
  _PublicMemory(
    id: 'pm01',
    title: 'Cherry Blossoms in Full Bloom',
    caption:
        'Walked under a tunnel of sakura petals. Time stood completely still.',
    imageUrl:
        'https://images.pexels.com/photos/2070485/pexels-photo-2070485.jpeg?w=800',
    semanticLabel:
        'Pink cherry blossom trees in full bloom lining a path in Tokyo park with soft pink petals falling',
    creatorName: 'Yuki',
    creatorAvatar:
        'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=100',
    creatorAvatarLabel: 'Young Japanese woman smiling softly',
    location: 'Ueno Park, Tokyo',
    timeAgo: '2 hours ago',
    reactions: 284,
    comments: 31,
  ),
  _PublicMemory(
    id: 'pm02',
    title: 'Street Food Evening',
    caption: 'Tlayudas, mezcal, and strangers who became friends by midnight.',
    imageUrl:
        'https://images.pexels.com/photos/2092507/pexels-photo-2092507.jpeg?w=800',
    semanticLabel:
        'Vibrant street food stall at night in Oaxaca Mexico with colorful lights and people eating',
    creatorName: 'Camila',
    creatorAvatar:
        'https://images.pexels.com/photos/1130626/pexels-photo-1130626.jpeg?w=100',
    creatorAvatarLabel: 'Young Latin woman with warm smile outdoors',
    location: 'Oaxaca, Mexico',
    timeAgo: '5 hours ago',
    reactions: 197,
    comments: 24,
  ),
  _PublicMemory(
    id: 'pm03',
    title: 'Rainy Evening Walk',
    caption:
        'The city smells different when it rains. Like it\'s breathing again.',
    imageUrl:
        'https://images.pexels.com/photos/1440476/pexels-photo-1440476.jpeg?w=800',
    semanticLabel:
        'Wet Mumbai street at night with reflections of orange and yellow lights on rain-soaked pavement',
    creatorName: 'Arjun',
    creatorAvatar:
        'https://images.pexels.com/photos/1681010/pexels-photo-1681010.jpeg?w=100',
    creatorAvatarLabel: 'Young Indian man with glasses smiling',
    location: 'Bandra, Mumbai',
    timeAgo: '1 day ago',
    reactions: 342,
    comments: 47,
  ),
  _PublicMemory(
    id: 'pm04',
    title: 'First Snow of the Year',
    caption: 'Woke up to silence. Looked outside and understood why.',
    imageUrl:
        'https://images.pexels.com/photos/3225517/pexels-photo-3225517.jpeg?w=800',
    semanticLabel:
        'Snow-covered Seoul street at dawn with soft white snowflakes falling on traditional rooftops',
    creatorName: 'Jisoo',
    creatorAvatar:
        'https://images.pexels.com/photos/1382731/pexels-photo-1382731.jpeg?w=100',
    creatorAvatarLabel: 'Young Korean woman in winter coat smiling',
    location: 'Bukchon, Seoul',
    timeAgo: '2 days ago',
    reactions: 521,
    comments: 68,
  ),
  _PublicMemory(
    id: 'pm05',
    title: 'Sunset by the Sea',
    caption:
        'The horizon turned gold and nobody said a word. We didn\'t need to.',
    imageUrl:
        'https://images.pexels.com/photos/1007657/pexels-photo-1007657.jpeg?w=800',
    semanticLabel:
        'Golden sunset over the Arabian Sea in Goa with silhouettes of palm trees and people on the beach',
    creatorName: 'Priya',
    creatorAvatar:
        'https://images.pexels.com/photos/1102341/pexels-photo-1102341.jpeg?w=100',
    creatorAvatarLabel:
        'Young Indian woman with long dark hair smiling at beach',
    location: 'Palolem Beach, Goa',
    timeAgo: '3 days ago',
    reactions: 408,
    comments: 52,
  ),
];

// ── Memory Themes ─────────────────────────────────────────────────────────────

class _MemoryTheme {
  final String label;
  final String emoji;
  final Color color;

  const _MemoryTheme({
    required this.label,
    required this.emoji,
    required this.color,
  });
}

final List<_MemoryTheme> _memoryThemes = [
  _MemoryTheme(label: 'Family', emoji: '🏡', color: const Color(0xFFFFB84D)),
  _MemoryTheme(
    label: 'First trips',
    emoji: '✈️',
    color: const Color(0xFF39FF8C),
  ),
  _MemoryTheme(
    label: 'Old friends',
    emoji: '🤝',
    color: const Color(0xFF00E5FF),
  ),
  _MemoryTheme(
    label: 'Little joys',
    emoji: '🌸',
    color: const Color(0xFFFF6B9D),
  ),
  _MemoryTheme(
    label: 'Summer nights',
    emoji: '🌙',
    color: const Color(0xFFB39DDB),
  ),
];

// ── Discover Screen ───────────────────────────────────────────────────────────

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  int _selectedFilter = 0;
  final List<String> _filters = ['For You', 'Nearby', 'Trending'];
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MemoryItem _buildMemoryItemFromPublic(_PublicMemory pm) {
    return MemoryItem(
      id: pm.id,
      title: pm.title,
      date: pm.timeAgo,
      imageUrl: pm.imageUrl,
      semanticLabel: pm.semanticLabel,
      circle: 'Public',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
      type: MemoryType.photo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBody: true,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _DiscoverHeader(
                  searchOpen: _searchOpen,
                  searchController: _searchController,
                  onSearchToggle: () {
                    setState(() {
                      _searchOpen = !_searchOpen;
                      if (!_searchOpen) _searchController.clear();
                    });
                    HapticFeedback.lightImpact();
                  },
                ),
              ),

              // ── Filter Pills ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _FilterPills(
                  filters: _filters,
                  selectedIndex: _selectedFilter,
                  onSelect: (i) {
                    setState(() => _selectedFilter = i);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),

              // ── Memory Feed ───────────────────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final pm = _publicMemories[index];
                  return _MemoryCard(
                    memory: pm,
                    onTap: () {
                      context.push(
                        AppRoutes.memoryDetailScreen,
                        extra: _buildMemoryItemFromPublic(pm),
                      );
                    },
                    onAvatarTap: () {
                      context.push(
                        AppRoutes.memberProfileScreen,
                        extra: {
                          'memberName': pm.creatorName,
                          'memberAvatarUrl': pm.creatorAvatar,
                        },
                      );
                    },
                  );
                }, childCount: _publicMemories.length),
              ),

              // ── People Are Remembering Section ────────────────────────────
              SliverToBoxAdapter(child: _PeopleRememberingSection()),

              // ── Bottom padding for nav bar ────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ── FAB ───────────────────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 96,
            child: _CaptureFAB(
              onTap: () => context.push(AppRoutes.createMemoryScreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DiscoverHeader extends StatelessWidget {
  final bool searchOpen;
  final TextEditingController searchController;
  final VoidCallback onSearchToggle;

  const _DiscoverHeader({
    required this.searchOpen,
    required this.searchController,
    required this.onSearchToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: GoogleFonts.manrope(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Moments worth remembering, from around the world.',
                      style: GoogleFonts.manrope(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Search toggle
              GestureDetector(
                onTap: onSearchToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: searchOpen
                        ? AppTheme.primaryGreenGlow
                        : AppTheme.surfaceVariantDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: searchOpen
                          ? AppTheme.primaryGreen.withAlpha(100)
                          : AppTheme.outline,
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    searchOpen ? Icons.close_rounded : Icons.search_rounded,
                    size: 20,
                    color: searchOpen
                        ? AppTheme.primaryGreen
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bell → Notifications
              GestureDetector(
                onTap: () => context.push(AppRoutes.notificationsScreen),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outline, width: 0.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.backgroundDark,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // User avatar → Profile
              GestureDetector(
                onTap: () => context.go(AppRoutes.profileScreen),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withAlpha(128),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://images.pexels.com/photos/3763188/pexels-photo-3763188.jpeg?w=100',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: searchOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariantDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withAlpha(80),
                          width: 0.8,
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search memories, places, people…',
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.textDisabled,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppTheme.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Filter Pills ──────────────────────────────────────────────────────────────

class _FilterPills extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _FilterPills({
    required this.filters,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: List.generate(filters.length, (i) {
          final isSelected = i == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < filters.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: isSelected ? null : AppTheme.surfaceVariantDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : AppTheme.outline,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  filters[i],
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Memory Card ───────────────────────────────────────────────────────────────

class _MemoryCard extends StatelessWidget {
  final _PublicMemory memory;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  const _MemoryCard({
    required this.memory,
    required this.onTap,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.outline, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ─────────────────────────────────────────────────────
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CachedNetworkImage(
                    imageUrl: memory.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.surfaceVariantDark,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.surfaceVariantDark,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.backgroundDark.withAlpha(180),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Public badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark.withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.cyanAccent.withAlpha(100),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: 10,
                          color: AppTheme.cyanAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Public',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Location bottom-left
                Positioned(
                  bottom: 10,
                  left: 12,
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: AppTheme.textSecondary.withAlpha(200),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        memory.location,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Content ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryGreen.withAlpha(120),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: memory.creatorAvatar,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppTheme.surfaceVariantDark),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.surfaceVariantDark,
                                child: const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: Text(
                          memory.creatorName,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        memory.timeAgo,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    memory.title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Caption
                  Text(
                    memory.caption,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Engagement row
                  Row(
                    children: [
                      _EngagementChip(
                        icon: Icons.favorite_border_rounded,
                        count: memory.reactions,
                        color: const Color(0xFFFF6B9D),
                      ),
                      const SizedBox(width: 12),
                      _EngagementChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: memory.comments,
                        color: AppTheme.cyanAccent,
                      ),
                    ],
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

class _EngagementChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _EngagementChip({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withAlpha(200)),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── People Are Remembering Section ───────────────────────────────────────────

class _PeopleRememberingSection extends StatelessWidget {
  const _PeopleRememberingSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'People are remembering…',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _memoryThemes.map((theme) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: theme.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.color.withAlpha(60),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(theme.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      theme.label,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Capture FAB ───────────────────────────────────────────────────────────────

class _CaptureFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _CaptureFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.black),
      ),
    );
  }
}
