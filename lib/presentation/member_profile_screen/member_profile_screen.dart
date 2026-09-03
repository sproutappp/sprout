import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/profile.dart';
import '../../services/circles_repository.dart';
import '../../services/memories_repository.dart';
import '../../services/profiles_repository.dart';
import '../memories_screen/widgets/memories_grid_widget.dart';

// ── Member Data Model ────────────────────────────────────────────────────
// Everything here comes from real data: the viewed member's own profile,
// circles they share with the CURRENT user (RLS on circle_members already
// scopes this — see CirclesRepository.fetchSharedCircles), and memories
// they added to those shared circles (same RLS guarantee on memories).
// There's no bio/username field in `profiles`, and no "people in common"
// count — those aren't invented here, just left out.

class MemberData {
  final String id;
  final String name;
  final String avatarUrl;
  final String? memberSince;
  final List<_MemberMemory> memories;
  final List<_MemberCircle> circles;

  const MemberData({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.memberSince,
    required this.memories,
    required this.circles,
  });

  int get memoriesCount => memories.length;
  int get circlesCount => circles.length;
}

class _MemberMemory {
  final String id;
  final String title;
  final String date;
  final String imageUrl;
  final String semanticLabel;
  final String circle;
  final Color circleColor;
  final MemoryPrivacy privacy;

  const _MemberMemory({
    required this.id,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.semanticLabel,
    required this.circle,
    required this.circleColor,
    required this.privacy,
  });
}

class _MemberCircle {
  final String id;
  final String name;
  final int memberCount;
  final String imageUrl;
  final String semanticLabel;
  final Color accent;

  const _MemberCircle({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.imageUrl,
    required this.semanticLabel,
    required this.accent,
  });
}

String _formatMemberSince(DateTime? dt) {
  if (dt == null) return '';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}


// ── Screen ────────────────────────────────────────────────────────────────────

class MemberProfileScreen extends StatefulWidget {
  final String? memberId;
  final String? memberName;
  final String? memberAvatarUrl;

  const MemberProfileScreen({
    super.key,
    this.memberId,
    this.memberName,
    this.memberAvatarUrl,
  });

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  MemberData? _member;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _load();
  }

  Future<void> _load() async {
    final memberId = widget.memberId;
    if (memberId == null) {
      // No real account link (e.g. an untagged "person" chip) — nothing
      // real to fetch. Show just the name/avatar we were given, no
      // fabricated stats or lists.
      setState(() {
        _member = MemberData(
          id: '',
          name: widget.memberName ?? 'Unknown',
          avatarUrl: widget.memberAvatarUrl ??
              'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=400',
          memories: const [],
          circles: const [],
        );
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await ProfilesRepository.fetchById(memberId);
      if (profile == null) {
        setState(() {
          _error = "Couldn't find this person.";
          _isLoading = false;
        });
        return;
      }

      final sharedCircles = await CirclesRepository.fetchSharedCircles(memberId);
      final theirMemories = await MemoriesRepository.fetchByUploader(memberId);

      const palette = [
        Color(0xFFFF8C39),
        Color(0xFF00E5FF),
        Color(0xFF39FF8C),
        Color(0xFFB839FF),
      ];

      if (!mounted) return;
      setState(() {
        _member = MemberData(
          id: profile.id,
          name: profile.displayName,
          avatarUrl: profile.avatarUrl ??
              'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=400',
          memberSince: _formatMemberSince(profile.createdAt),
          circles: [
            for (var i = 0; i < sharedCircles.length; i++)
              _MemberCircle(
                id: sharedCircles[i].id,
                name: sharedCircles[i].name,
                memberCount: sharedCircles[i].memberCount,
                imageUrl: sharedCircles[i].coverImageUrl ??
                    'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=400',
                semanticLabel: '${sharedCircles[i].name} circle cover photo',
                accent: palette[i % palette.length],
              ),
          ],
          memories: [
            for (final m in theirMemories)
              _MemberMemory(
                id: m.id,
                title: m.caption?.isNotEmpty == true ? m.caption! : 'A shared memory',
                date: '${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}',
                imageUrl: m.imageUrl,
                semanticLabel: 'Shared memory photo',
                circle: m.circleName ?? 'Circle',
                circleColor: AppTheme.primaryGreen,
                privacy: MemoryPrivacy.circle,
              ),
          ],
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load this profile.";
        _isLoading = false;
      });
    }
  }

  void _showThreeDotMenu() {
    final member = _member;
    if (member == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberMenuSheet(memberName: member.name),
    );
  }

  void _openMemoryDetail(_MemberMemory m) {
    final item = MemoryItem(
      id: m.id,
      title: m.title,
      date: m.date,
      imageUrl: m.imageUrl,
      semanticLabel: m.semanticLabel,
      circle: m.circle,
      circleColor: m.circleColor,
      privacy: m.privacy,
      type: MemoryType.photo,
    );
    context.push(AppRoutes.memoryDetailScreen, extra: item);
  }

  void _openCircleDetail(String circleId) {
    context.push(AppRoutes.circleDetailScreen, extra: circleId);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_error != null || _member == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            _error ?? 'Profile not found.',
            style: GoogleFonts.manrope(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final member = _member!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Subtle radial background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.8),
                radius: 1.2,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),

          // Scrollable content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Top bar ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _TopBar(
                  topPadding: topPadding,
                  onBack: () => context.pop(),
                  onMenu: _showThreeDotMenu,
                ),
              ),

              // ── Profile Header ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: _ProfileHeader(member: member),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Stats Row ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatsRow(member: member),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Memories Section ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(
                    title: 'Memories',
                    trailing: member.memories.length > 3
                        ? GestureDetector(
                            onTap: () {},
                            child: Text(
                              'See all',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final m = member.memories[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemoryRow(
                          memory: m,
                          onTap: () => _openMemoryDetail(m),
                        ),
                      );
                    },
                    childCount: member.memories.length > 4
                        ? 4
                        : member.memories.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Circles Section ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(
                    title: 'Circles',
                    trailing: member.circles.length > 3
                        ? GestureDetector(
                            onTap: () {},
                            child: Text(
                              'See all',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final c = member.circles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CircleRow(
                          circle: c,
                          onTap: () => _openCircleDetail(c.id),
                        ),
                      );
                    },
                    childCount: member.circles.length > 3
                        ? 3
                        : member.circles.length,
                  ),
                ),
              ),

              // Bottom padding for FAB + nav
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 110)),
            ],
          ),

          // ── Floating "+" Create Memory button ────────────────────────────
          Positioned(
            right: 20,
            bottom: bottomPadding + 80,
            child: _CaptureFAB(
              onTap: () => context.push(AppRoutes.createMemoryScreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  const _TopBar({
    required this.topPadding,
    required this.onBack,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
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
                color: AppTheme.surfaceVariantDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.outline, width: 0.8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
          ),
          // Three-dot menu
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.outline, width: 0.8),
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final MemberData member;

  const _ProfileHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Avatar with accent ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
              ),
              // White gap ring
              Container(
                width: 94,
                height: 94,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.backgroundDark,
                ),
              ),
              // Avatar
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: member.avatarUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 88,
                    height: 88,
                    color: AppTheme.surfaceVariantDark,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: AppTheme.surfaceVariantDark,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Name
          Text(
            member.name,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Member since
          if (member.memberSince != null && member.memberSince!.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.eco_rounded,
                  size: 12,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Member since ${member.memberSince}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final MemberData member;

  const _StatsRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline, width: 0.6),
      ),
      child: Row(
        children: [
          _StatItem(
            value: '${member.memoriesCount}',
            label: 'Memories',
            color: AppTheme.primaryGreen,
          ),
          _StatDivider(),
          _StatItem(
            value: '${member.circlesCount}',
            label: 'Circles',
            color: AppTheme.cyanAccent,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
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
  final _MemberMemory memory;
  final VoidCallback onTap;

  const _MemoryRow({required this.memory, required this.onTap});

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
                imageUrl: memory.imageUrl,
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
                    // Date
                    Row(
                      children: [
                        const Icon(
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
                      ],
                    ),
                    // Circle / privacy badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: memory.circleColor.withAlpha(22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: memory.circleColor.withAlpha(70),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                memory.privacy == MemoryPrivacy.public
                                    ? Icons.public_rounded
                                    : Icons.group_rounded,
                                size: 10,
                                color: memory.circleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                memory.privacy == MemoryPrivacy.public
                                    ? 'Public'
                                    : memory.circle,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: memory.circleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Chevron
            const Padding(
              padding: EdgeInsets.only(right: 12),
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

// ── Circle Row ────────────────────────────────────────────────────────────────

class _CircleRow extends StatelessWidget {
  final _MemberCircle circle;
  final VoidCallback onTap;

  const _CircleRow({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: circle.accent.withAlpha(40), width: 0.8),
        ),
        child: Row(
          children: [
            // Circle image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: circle.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 48,
                  height: 48,
                  color: AppTheme.surfaceVariantDark,
                  child: const Icon(
                    Icons.group_rounded,
                    size: 22,
                    color: AppTheme.textDisabled,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppTheme.surfaceVariantDark,
                  child: const Icon(
                    Icons.group_rounded,
                    size: 22,
                    color: AppTheme.textDisabled,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Name + member count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    circle.name,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${circle.memberCount} members',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: circle.accent.withAlpha(180),
            ),
          ],
        ),
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
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withAlpha(100),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }
}

// ── Three-dot Menu Sheet ──────────────────────────────────────────────────────

class _MemberMenuSheet extends StatelessWidget {
  final String memberName;

  const _MemberMenuSheet({required this.memberName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              memberName,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(height: 0.5, color: AppTheme.outline),
          // Report
          _MenuAction(
            icon: Icons.flag_outlined,
            label: 'Report',
            color: AppTheme.textSecondary,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Report submitted. Thank you.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  backgroundColor: AppTheme.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          Container(height: 0.5, color: AppTheme.outline),
          // Block
          _MenuAction(
            icon: Icons.block_rounded,
            label: 'Block',
            color: AppTheme.error,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$memberName has been blocked.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}