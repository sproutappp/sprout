import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../memories_screen/widgets/memories_grid_widget.dart';

// ── Sample Data ───────────────────────────────────────────────────────────────

class CircleDetailData {
  final String id;
  final String name;
  final String subtitle;
  final int memberCount;
  final int memoryCount;
  final String coverUrl;
  final String coverSemanticLabel;
  final Color accentColor;
  final List<_MemberData> members;
  final List<_CircleMemory> recentMemories;

  const CircleDetailData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.memberCount,
    required this.memoryCount,
    required this.coverUrl,
    required this.coverSemanticLabel,
    required this.accentColor,
    required this.members,
    required this.recentMemories,
  });
}

class _MemberData {
  final String name;
  final String avatarUrl;
  final String semanticLabel;

  const _MemberData({
    required this.name,
    required this.avatarUrl,
    required this.semanticLabel,
  });
}

class _CircleMemory {
  final String id;
  final String title;
  final String date;
  final String contributor;
  final String thumbnailUrl;
  final String semanticLabel;
  final int reactions;
  final int comments;

  const _CircleMemory({
    required this.id,
    required this.title,
    required this.date,
    required this.contributor,
    required this.thumbnailUrl,
    required this.semanticLabel,
    required this.reactions,
    required this.comments,
  });
}

final CircleDetailData _familyCircle = CircleDetailData(
  id: 'c01',
  name: 'Family',
  subtitle: 'The people who feel like home.',
  memberCount: 8,
  memoryCount: 42,
  coverUrl:
      'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=800',
  coverSemanticLabel:
      'Happy family group sitting together outdoors in warm golden sunlight',
  accentColor: const Color(0xFFFFB84D),
  members: const [
    _MemberData(
      name: 'Mom',
      avatarUrl:
          'https://images.pexels.com/photos/1181686/pexels-photo-1181686.jpeg?w=200',
      semanticLabel: 'Middle-aged woman smiling warmly with short dark hair',
    ),
    _MemberData(
      name: 'Dad',
      avatarUrl:
          'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?w=200',
      semanticLabel: 'Mature man with grey temples smiling in casual attire',
    ),
    _MemberData(
      name: 'Grandma',
      avatarUrl:
          'https://images.pexels.com/photos/1729931/pexels-photo-1729931.jpeg?w=200',
      semanticLabel: 'Elderly woman with white hair smiling at birthday party',
    ),
    _MemberData(
      name: 'Priya',
      avatarUrl:
          'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?w=200',
      semanticLabel: 'Young woman with long dark hair smiling outdoors',
    ),
    _MemberData(
      name: 'Arjun',
      avatarUrl:
          'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?w=200',
      semanticLabel: 'Young man in casual shirt smiling confidently',
    ),
    _MemberData(
      name: 'Nani',
      avatarUrl:
          'https://images.pexels.com/photos/1181424/pexels-photo-1181424.jpeg?w=200',
      semanticLabel: 'Older woman with glasses smiling gently indoors',
    ),
    _MemberData(
      name: 'Rohan',
      avatarUrl:
          'https://images.pexels.com/photos/614810/pexels-photo-614810.jpeg?w=200',
      semanticLabel: 'Young man with short hair and friendly smile',
    ),
    _MemberData(
      name: 'Meera',
      avatarUrl:
          'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=200',
      semanticLabel: 'Young woman with curly hair smiling in natural light',
    ),
  ],
  recentMemories: const [
    _CircleMemory(
      id: 'fm01',
      title: "Grandma's 80th Birthday",
      date: 'Aug 22, 2026',
      contributor: 'Priya',
      thumbnailUrl:
          'https://images.pexels.com/photos/1729931/pexels-photo-1729931.jpeg?w=300',
      semanticLabel:
          'Elderly woman smiling surrounded by family at birthday celebration',
      reactions: 14,
      comments: 7,
    ),
    _CircleMemory(
      id: 'fm02',
      title: 'Sunday Lunch at Home',
      date: 'Aug 10, 2026',
      contributor: 'Mom',
      thumbnailUrl:
          'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?w=300',
      semanticLabel:
          'Colorful home-cooked meal spread on a wooden dining table',
      reactions: 9,
      comments: 3,
    ),
    _CircleMemory(
      id: 'fm03',
      title: 'Monsoon Evening on the Terrace',
      date: 'Jul 28, 2026',
      contributor: 'Arjun',
      thumbnailUrl:
          'https://images.pexels.com/photos/1118873/pexels-photo-1118873.jpeg?w=300',
      semanticLabel:
          'Rainy evening view from a rooftop terrace with city lights below',
      reactions: 11,
      comments: 5,
    ),
    _CircleMemory(
      id: 'fm04',
      title: "Dad's Retirement Celebration",
      date: 'Jul 15, 2026',
      contributor: 'Rohan',
      thumbnailUrl:
          'https://images.pexels.com/photos/3171837/pexels-photo-3171837.jpeg?w=300',
      semanticLabel:
          'Family gathered around a man holding a retirement gift with big smiles',
      reactions: 22,
      comments: 12,
    ),
    _CircleMemory(
      id: 'fm05',
      title: 'Diwali Night Lights',
      date: 'Jun 30, 2026',
      contributor: 'Meera',
      thumbnailUrl:
          'https://images.pexels.com/photos/1405528/pexels-photo-1405528.jpeg?w=300',
      semanticLabel:
          'Rows of glowing diyas and colorful rangoli on a dark floor at night',
      reactions: 18,
      comments: 8,
    ),
  ],
);

// ── Screen ────────────────────────────────────────────────────────────────────

class CircleDetailScreen extends StatefulWidget {
  final String? circleId;

  const CircleDetailScreen({super.key, this.circleId});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  final CircleDetailData _circle = _familyCircle;

  void _openInviteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(circleName: _circle.name),
    );
  }

  void _openSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CircleSettingsSheet(circleName: _circle.name),
    );
  }

  void _openCaptureMemory() {
    context.push(AppRoutes.createMemoryScreen);
  }

  void _openMemoryDetail(_CircleMemory memory) {
    // Map to MemoryItem for the existing detail screen
    final item = MemoryItem(
      id: memory.id,
      title: memory.title,
      date: memory.date,
      imageUrl: memory.thumbnailUrl,
      semanticLabel: memory.semanticLabel,
      circle: _circle.name,
      circleColor: _circle.accentColor,
      privacy: MemoryPrivacy.circle,
      type: MemoryType.photo,
    );
    context.push(AppRoutes.memoryDetailScreen, extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Cover + Header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _CoverHeader(
                  circle: _circle,
                  topPadding: topPadding,
                  onBack: () => context.pop(),
                  onInvite: _openInviteSheet,
                  onSettings: _openSettingsMenu,
                ),
              ),

              // ── Stats row ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _StatsRow(circle: _circle),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Recent Memories ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(title: 'Recent Memories'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final m = _circle.recentMemories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemoryRow(
                        memory: m,
                        accentColor: _circle.accentColor,
                        onTap: () => _openMemoryDetail(m),
                      ),
                    );
                  }, childCount: _circle.recentMemories.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── People in this Circle ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(
                    title: 'People in this Circle',
                    trailing: GestureDetector(
                      onTap: () {},
                      child: Text(
                        'See all',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _PeopleRow(members: _circle.members)),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Invite People secondary action ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _InvitePeopleButton(onTap: _openInviteSheet),
                ),
              ),

              // Bottom padding for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),

          // ── Floating "+ Capture Memory" button ──────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            right: 20,
            child: _CaptureMemoryFAB(onTap: _openCaptureMemory),
          ),
        ],
      ),
    );
  }
}

// ── Cover Header ──────────────────────────────────────────────────────────────

class _CoverHeader extends StatelessWidget {
  final CircleDetailData circle;
  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onInvite;
  final VoidCallback onSettings;

  const _CoverHeader({
    required this.circle,
    required this.topPadding,
    required this.onBack,
    required this.onInvite,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cover photo
        SizedBox(
          height: 280,
          width: double.infinity,
          child: CachedNetworkImage(
            imageUrl: circle.coverUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppTheme.surfaceVariantDark,
              child: const Center(
                child: Icon(
                  Icons.group_rounded,
                  size: 48,
                  color: AppTheme.textDisabled,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppTheme.surfaceVariantDark,
              child: const Center(
                child: Icon(
                  Icons.group_rounded,
                  size: 48,
                  color: AppTheme.textDisabled,
                ),
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
                  Colors.black.withAlpha(80),
                  Colors.transparent,
                  AppTheme.backgroundDark.withAlpha(200),
                  AppTheme.backgroundDark,
                ],
                stops: const [0.0, 0.35, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // Top bar: back + three-dot
        Positioned(
          top: topPadding + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              // Right side: bell + avatar + three-dot
              Row(
                children: [
                  // Bell icon → Notifications
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.notificationsScreen),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(30),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
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
                          color: Colors.white.withAlpha(60),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://images.pexels.com/photos/3763188/pexels-photo-3763188.jpeg?w=100',
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppTheme.surfaceVariantDark),
                          errorWidget: (_, __, ___) => Container(
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
                  const SizedBox(width: 8),
                  // Three-dot menu
                  GestureDetector(
                    onTap: onSettings,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(30),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bottom info: name, subtitle, members, invite
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circle name
              Text(
                circle.name,
                style: GoogleFonts.manrope(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                circle.subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              // Member avatars + count + invite
              Row(
                children: [
                  // Overlapping avatars
                  _OverlappingAvatars(members: circle.members),
                  const SizedBox(width: 10),
                  Text(
                    '${circle.memberCount} members',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // Invite button
                  GestureDetector(
                    onTap: onInvite,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withAlpha(60),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_add_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Invite',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Overlapping Avatars ───────────────────────────────────────────────────────

class _OverlappingAvatars extends StatelessWidget {
  final List<_MemberData> members;

  const _OverlappingAvatars({required this.members});

  @override
  Widget build(BuildContext context) {
    final visible = members.take(5).toList();
    const double size = 28;
    const double overlap = 10;

    return SizedBox(
      width: size + (visible.length - 1) * (size - overlap),
      height: size,
      child: Stack(
        children: List.generate(visible.length, (i) {
          return Positioned(
            left: i * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.backgroundDark, width: 1.5),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: visible[i].avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.surfaceVariantDark,
                    child: const Icon(
                      Icons.person,
                      size: 14,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surfaceVariantDark,
                    child: const Icon(
                      Icons.person,
                      size: 14,
                      color: AppTheme.textDisabled,
                    ),
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

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CircleDetailData circle;

  const _StatsRow({required this.circle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: circle.accentColor.withAlpha(40), width: 0.8),
      ),
      child: Row(
        children: [
          _StatItem(
            value: '${circle.memoryCount}',
            label: 'Memories',
            icon: Icons.photo_album_rounded,
            color: circle.accentColor,
          ),
          _StatDivider(),
          _StatItem(
            value: '${circle.memberCount}',
            label: 'Members',
            icon: Icons.people_rounded,
            color: AppTheme.cyanAccent,
          ),
          _StatDivider(),
          // Active indicator
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withAlpha(160),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Active',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'recently',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.8,
      height: 36,
      color: AppTheme.outline,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Memory Row ────────────────────────────────────────────────────────────────

class _MemoryRow extends StatelessWidget {
  final _CircleMemory memory;
  final Color accentColor;
  final VoidCallback onTap;

  const _MemoryRow({
    required this.memory,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline, width: 0.6),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: memory.thumbnailUrl,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 88,
                  height: 88,
                  color: AppTheme.surfaceVariantDark,
                  child: const Icon(
                    Icons.image_rounded,
                    size: 28,
                    color: AppTheme.textDisabled,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 88,
                  height: 88,
                  color: AppTheme.surfaceVariantDark,
                  child: const Icon(
                    Icons.image_rounded,
                    size: 28,
                    color: AppTheme.textDisabled,
                  ),
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      memory.title,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Date + contributor
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: AppTheme.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          memory.date,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.textDisabled,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          memory.contributor,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    // Reactions + comments
                    Row(
                      children: [
                        _EngagementChip(
                          icon: Icons.favorite_rounded,
                          count: memory.reactions,
                          color: const Color(0xFFFF7EB3),
                        ),
                        const SizedBox(width: 10),
                        _EngagementChip(
                          icon: Icons.chat_bubble_rounded,
                          count: memory.comments,
                          color: AppTheme.cyanAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Chevron
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
      children: [
        Icon(icon, size: 12, color: color.withAlpha(200)),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── People Row ────────────────────────────────────────────────────────────────

class _PeopleRow extends StatelessWidget {
  final List<_MemberData> members;

  const _PeopleRow({required this.members});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final member = members[index];
          return GestureDetector(
            onTap: () {
              context.push(
                AppRoutes.memberProfileScreen,
                extra: {
                  'memberName': member.name,
                  'memberAvatarUrl': member.avatarUrl,
                },
              );
            },
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withAlpha(60),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: member.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.person,
                          size: 24,
                          color: AppTheme.textDisabled,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.person,
                          size: 24,
                          color: AppTheme.textDisabled,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member.name,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Capture Memory FAB ────────────────────────────────────────────────────────

class _CaptureMemoryFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _CaptureMemoryFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withAlpha(80),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.black),
      ),
    );
  }
}

// ── Invite People Button ──────────────────────────────────────────────────────

class _InvitePeopleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InvitePeopleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryGreen.withAlpha(50),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_rounded,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 8),
            Text(
              'Invite People',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invite Sheet ──────────────────────────────────────────────────────────────

class _InviteSheet extends StatelessWidget {
  final String circleName;

  const _InviteSheet({required this.circleName});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Invite to $circleName',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share a link or search for people',
            style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          // Share link row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outline, width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share invite link',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'sprout.app/join/family-xyz',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Copy',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Done',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circle Settings Sheet ─────────────────────────────────────────────────────

class _CircleSettingsSheet extends StatelessWidget {
  final String circleName;

  const _CircleSettingsSheet({required this.circleName});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final options = [
      (Icons.edit_rounded, 'Edit Circle', AppTheme.textPrimary),
      (Icons.person_add_rounded, 'Invite People', AppTheme.primaryGreen),
      (Icons.notifications_rounded, 'Notifications', AppTheme.textPrimary),
      (Icons.exit_to_app_rounded, 'Leave Circle', AppTheme.error),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            circleName,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Circle settings',
            style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          ...options.map(
            (opt) => GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outline, width: 0.6),
                ),
                child: Row(
                  children: [
                    Icon(opt.$1, size: 20, color: opt.$3),
                    const SizedBox(width: 12),
                    Text(
                      opt.$2,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: opt.$3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
