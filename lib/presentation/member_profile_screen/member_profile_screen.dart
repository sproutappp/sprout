import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../memories_screen/widgets/memories_grid_widget.dart';

// ── Member Data Model ─────────────────────────────────────────────────────────

class MemberData {
  final String id;
  final String name;
  final String username;
  final String bio;
  final String avatarUrl;
  final String avatarSemanticLabel;
  final String memberSince;
  final int memoriesCount;
  final int circlesCount;
  final int peopleCount;
  final bool isInCircle;
  final List<_MemberMemory> memories;
  final List<_MemberCircle> circles;

  const MemberData({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.avatarSemanticLabel,
    required this.memberSince,
    required this.memoriesCount,
    required this.circlesCount,
    required this.peopleCount,
    required this.isInCircle,
    required this.memories,
    required this.circles,
  });
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

// ── Mock Member Profiles ──────────────────────────────────────────────────────

final MemberData _priyaProfile = MemberData(
  id: 'u_priya',
  name: 'Priya Sharma',
  username: '@priya',
  bio: 'Chasing sunsets and saving memories. 🌅',
  avatarUrl:
      'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?w=400',
  avatarSemanticLabel:
      'Young woman with long dark hair smiling warmly outdoors in natural light',
  memberSince: 'Aug 2026',
  memoriesCount: 38,
  circlesCount: 3,
  peopleCount: 22,
  isInCircle: true,
  memories: const [
    _MemberMemory(
      id: 'pm_p01',
      title: 'Sunset by the Sea',
      date: 'Aug 24, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1007657/pexels-photo-1007657.jpeg?w=400',
      semanticLabel:
          'Golden sunset over the Arabian Sea in Goa with silhouettes of palm trees',
      circle: 'Adventure Crew',
      circleColor: AppTheme.primaryGreen,
      privacy: MemoryPrivacy.public,
    ),
    _MemberMemory(
      id: 'pm_p02',
      title: "Grandma's 80th Birthday",
      date: 'Aug 22, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1729931/pexels-photo-1729931.jpeg?w=400',
      semanticLabel:
          'Elderly woman smiling surrounded by family at birthday celebration',
      circle: 'Family',
      circleColor: Color(0xFFFFB84D),
      privacy: MemoryPrivacy.circle,
    ),
    _MemberMemory(
      id: 'pm_p03',
      title: 'Cherry Blossoms Walk',
      date: 'Aug 10, 2026',
      imageUrl:
          'https://images.pexels.com/photos/2070485/pexels-photo-2070485.jpeg?w=400',
      semanticLabel:
          'Pink cherry blossom trees in full bloom lining a path with soft petals falling',
      circle: 'College Friends',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
    ),
    _MemberMemory(
      id: 'pm_p04',
      title: 'Monsoon Evening on the Terrace',
      date: 'Jul 28, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1118873/pexels-photo-1118873.jpeg?w=400',
      semanticLabel:
          'Rainy evening view from a rooftop terrace with city lights below',
      circle: 'Family',
      circleColor: Color(0xFFFFB84D),
      privacy: MemoryPrivacy.circle,
    ),
  ],
  circles: const [
    _MemberCircle(
      id: 'c01',
      name: 'Family',
      memberCount: 8,
      imageUrl:
          'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=120',
      semanticLabel: 'Happy family group sitting together outdoors',
      accent: Color(0xFFFFB84D),
    ),
    _MemberCircle(
      id: 'c03',
      name: 'Adventure Crew',
      memberCount: 5,
      imageUrl:
          'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=120',
      semanticLabel: 'Hikers on mountain trail at sunrise',
      accent: AppTheme.primaryGreen,
    ),
    _MemberCircle(
      id: 'c02',
      name: 'College Friends',
      memberCount: 14,
      imageUrl:
          'https://images.pexels.com/photos/1438072/pexels-photo-1438072.jpeg?w=120',
      semanticLabel: 'Group of young college students laughing together',
      accent: AppTheme.cyanAccent,
    ),
  ],
);

final MemberData _arjunProfile = MemberData(
  id: 'u_arjun',
  name: 'Arjun Mehta',
  username: '@arjun',
  bio: 'Mountains, monsoons, and midnight chai. ☕🏔️',
  avatarUrl:
      'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?w=400',
  avatarSemanticLabel:
      'Young man in casual shirt smiling confidently in natural light',
  memberSince: 'Aug 2026',
  memoriesCount: 27,
  circlesCount: 4,
  peopleCount: 18,
  isInCircle: true,
  memories: const [
    _MemberMemory(
      id: 'pm_a01',
      title: 'Sunrise at Mullayanagiri',
      date: 'Aug 26, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=400',
      semanticLabel:
          'Golden sunrise breaking over misty mountain peaks with silhouetted trees',
      circle: 'Adventure Crew',
      circleColor: AppTheme.primaryGreen,
      privacy: MemoryPrivacy.circle,
    ),
    _MemberMemory(
      id: 'pm_a02',
      title: 'Rainy Evening Walk',
      date: 'Aug 18, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1440476/pexels-photo-1440476.jpeg?w=400',
      semanticLabel:
          'Wet Mumbai street at night with reflections of orange and yellow lights on rain-soaked pavement',
      circle: 'College Friends',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
    ),
    _MemberMemory(
      id: 'pm_a03',
      title: 'Monsoon Drive to Coorg',
      date: 'Aug 15, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1287145/pexels-photo-1287145.jpeg?w=400',
      semanticLabel:
          'Winding road through lush green coffee plantations in heavy monsoon rain',
      circle: 'Adventure Crew',
      circleColor: AppTheme.primaryGreen,
      privacy: MemoryPrivacy.circle,
    ),
    _MemberMemory(
      id: 'pm_a04',
      title: 'Late Night Chai',
      date: 'Aug 12, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1638280/pexels-photo-1638280.jpeg?w=400',
      semanticLabel:
          'Two ceramic cups of chai on a wooden café table with warm amber lighting',
      circle: 'College Friends',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
    ),
  ],
  circles: const [
    _MemberCircle(
      id: 'c01',
      name: 'Family',
      memberCount: 8,
      imageUrl:
          'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=120',
      semanticLabel: 'Happy family group sitting together outdoors',
      accent: Color(0xFFFFB84D),
    ),
    _MemberCircle(
      id: 'c03',
      name: 'Adventure Crew',
      memberCount: 5,
      imageUrl:
          'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=120',
      semanticLabel: 'Hikers on mountain trail at sunrise',
      accent: AppTheme.primaryGreen,
    ),
    _MemberCircle(
      id: 'c02',
      name: 'College Friends',
      memberCount: 14,
      imageUrl:
          'https://images.pexels.com/photos/1438072/pexels-photo-1438072.jpeg?w=120',
      semanticLabel: 'Group of young college students laughing together',
      accent: AppTheme.cyanAccent,
    ),
    _MemberCircle(
      id: 'c04',
      name: 'Best Friends',
      memberCount: 4,
      imageUrl:
          'https://images.pexels.com/photos/1024993/pexels-photo-1024993.jpeg?w=120',
      semanticLabel: 'Close friends smiling together outdoors',
      accent: Color(0xFFFF6B9D),
    ),
  ],
);

// Fallback generic profile for any unknown member id
MemberData _buildFallbackMember(String name, String avatarUrl) => MemberData(
  id: 'u_unknown',
  name: name,
  username: '@${name.toLowerCase().replaceAll(' ', '')}',
  bio: 'Collecting little moments that matter.',
  avatarUrl: avatarUrl,
  avatarSemanticLabel: 'Person smiling in natural light',
  memberSince: 'Aug 2026',
  memoriesCount: 12,
  circlesCount: 2,
  peopleCount: 9,
  isInCircle: false,
  memories: const [
    _MemberMemory(
      id: 'pm_fb01',
      title: 'A Quiet Morning',
      date: 'Aug 20, 2026',
      imageUrl:
          'https://images.pexels.com/photos/1417945/pexels-photo-1417945.jpeg?w=400',
      semanticLabel:
          'Steaming cup of tea on a wooden table in warm morning light',
      circle: 'Public',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
    ),
  ],
  circles: const [
    _MemberCircle(
      id: 'c01',
      name: 'Family',
      memberCount: 8,
      imageUrl:
          'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=120',
      semanticLabel: 'Happy family group sitting together outdoors',
      accent: Color(0xFFFFB84D),
    ),
  ],
);

// Lookup map
final Map<String, MemberData> _memberProfiles = {
  'u_priya': _priyaProfile,
  'priya': _priyaProfile,
  'u_arjun': _arjunProfile,
  'arjun': _arjunProfile,
};

MemberData resolveMemberProfile({
  String? memberId,
  String? name,
  String? avatarUrl,
}) {
  if (memberId != null) {
    final key = memberId.toLowerCase();
    if (_memberProfiles.containsKey(key)) return _memberProfiles[key]!;
  }
  if (name != null) {
    final key = name.toLowerCase();
    if (_memberProfiles.containsKey(key)) return _memberProfiles[key]!;
  }
  return _buildFallbackMember(
    name ?? 'Unknown',
    avatarUrl ??
        'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=400',
  );
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
  late MemberData _member;
  late bool _isInCircle;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _member = resolveMemberProfile(
      memberId: widget.memberId,
      name: widget.memberName,
      avatarUrl: widget.memberAvatarUrl,
    );
    _isInCircle = _member.isInCircle;
  }

  void _toggleCircle() {
    HapticFeedback.lightImpact();
    setState(() => _isInCircle = !_isInCircle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isInCircle
              ? '${_member.name} added to your Circle'
              : '${_member.name} removed from your Circle',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showThreeDotMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberMenuSheet(memberName: _member.name),
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
                child: _ProfileHeader(
                  member: _member,
                  isInCircle: _isInCircle,
                  onToggleCircle: _toggleCircle,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Stats Row ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatsRow(member: _member),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Memories Section ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(
                    title: 'Memories',
                    trailing: _member.memories.length > 3
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
                      final m = _member.memories[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemoryRow(
                          memory: m,
                          onTap: () => _openMemoryDetail(m),
                        ),
                      );
                    },
                    childCount: _member.memories.length > 4
                        ? 4
                        : _member.memories.length,
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
                    trailing: _member.circles.length > 3
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
                      final c = _member.circles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CircleRow(
                          circle: c,
                          onTap: () => _openCircleDetail(c.id),
                        ),
                      );
                    },
                    childCount: _member.circles.length > 3
                        ? 3
                        : _member.circles.length,
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
  final bool isInCircle;
  final VoidCallback onToggleCircle;

  const _ProfileHeader({
    required this.member,
    required this.isInCircle,
    required this.onToggleCircle,
  });

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

          const SizedBox(height: 3),

          // Username
          Text(
            member.username,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen,
            ),
          ),

          const SizedBox(height: 8),

          // Bio
          Text(
            member.bio,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 6),

          // Member since
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

          // Add to Circle / In Circle button
          GestureDetector(
            onTap: onToggleCircle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: isInCircle ? null : AppTheme.primaryGradient,
                color: isInCircle ? AppTheme.surfaceVariantDark : null,
                borderRadius: BorderRadius.circular(24),
                border: isInCircle
                    ? Border.all(
                        color: AppTheme.primaryGreen.withAlpha(100),
                        width: 1.0,
                      )
                    : null,
                boxShadow: isInCircle
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withAlpha(60),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isInCircle
                        ? Icons.check_circle_rounded
                        : Icons.person_add_rounded,
                    size: 16,
                    color: isInCircle ? AppTheme.primaryGreen : Colors.black,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isInCircle ? 'In Circle' : 'Add to Circle',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isInCircle ? AppTheme.primaryGreen : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          _StatDivider(),
          _StatItem(
            value: '${member.peopleCount}',
            label: 'People',
            color: const Color(0xFFFFB84D),
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