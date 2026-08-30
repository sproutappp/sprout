import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

// ── Sample data ───────────────────────────────────────────────────────────────

class _MemoryPreview {
  final String title;
  final String date;
  final String imageUrl;
  final String semanticLabel;

  const _MemoryPreview({
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.semanticLabel,
  });
}

const List<_MemoryPreview> _myMemories = [
  _MemoryPreview(
    title: 'Sunrise at Mullayanagiri',
    date: 'Aug 12',
    imageUrl:
        'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=300',
    semanticLabel: 'Golden sunrise over misty mountain peaks with orange sky',
  ),
  _MemoryPreview(
    title: "Grandma's 80th Birthday",
    date: 'Aug 5',
    imageUrl:
        'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=300',
    semanticLabel:
        'Elderly woman smiling surrounded by family at birthday celebration',
  ),
  _MemoryPreview(
    title: 'Late night chai',
    date: 'Jul 28',
    imageUrl:
        'https://images.pexels.com/photos/1417945/pexels-photo-1417945.jpeg?w=300',
    semanticLabel:
        'Steaming cup of chai tea on wooden table in warm evening light',
  ),
  _MemoryPreview(
    title: 'College Farewell',
    date: 'Jul 15',
    imageUrl:
        'https://images.pexels.com/photos/1438072/pexels-photo-1438072.jpeg?w=300',
    semanticLabel:
        'Group of young college students laughing together on campus',
  ),
];

class _CircleRow {
  final String name;
  final int memberCount;
  final String imageUrl;
  final String semanticLabel;
  final Color accent;

  const _CircleRow({
    required this.name,
    required this.memberCount,
    required this.imageUrl,
    required this.semanticLabel,
    required this.accent,
  });
}

const List<_CircleRow> _myCircles = [
  _CircleRow(
    name: 'Family',
    memberCount: 8,
    imageUrl:
        'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=120',
    semanticLabel: 'Happy family group sitting together outdoors',
    accent: Color(0xFFFFB84D),
  ),
  _CircleRow(
    name: 'College Friends',
    memberCount: 14,
    imageUrl:
        'https://images.pexels.com/photos/1438072/pexels-photo-1438072.jpeg?w=120',
    semanticLabel: 'Group of young college students laughing together',
    accent: Color(0xFF39FF8C),
  ),
  _CircleRow(
    name: 'Adventure Crew',
    memberCount: 5,
    imageUrl:
        'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=120',
    semanticLabel: 'Hikers on mountain trail at sunrise',
    accent: Color(0xFF00E5FF),
  ),
  _CircleRow(
    name: 'Best Friends',
    memberCount: 4,
    imageUrl:
        'https://images.pexels.com/photos/1024993/pexels-photo-1024993.jpeg?w=120',
    semanticLabel: 'Close friends smiling together outdoors',
    accent: Color(0xFFFF6B9D),
  ),
];

// ── Account action rows ───────────────────────────────────────────────────────

class _AccountAction {
  final IconData icon;
  final String label;
  final bool isDanger;

  const _AccountAction({
    required this.icon,
    required this.label,
    this.isDanger = false,
  });
}

const List<_AccountAction> _accountActions = [
  _AccountAction(icon: Icons.edit_outlined, label: 'Edit Profile'),
  _AccountAction(icon: Icons.notifications_outlined, label: 'Notifications'),
  _AccountAction(icon: Icons.lock_outline_rounded, label: 'Privacy'),
  _AccountAction(icon: Icons.settings_outlined, label: 'Settings'),
  _AccountAction(icon: Icons.logout_rounded, label: 'Sign Out', isDanger: true),
];

// ── ProfileScreen ─────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariantDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.manrope(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You\'ll be signed out of your Sprout account.',
          style: GoogleFonts.manrope(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.signUpLoginScreen);
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.manrope(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAccountActionTap(_AccountAction action) {
    if (action.isDanger) {
      _showSignOutDialog();
      return;
    }
    if (action.label == 'Edit Profile') {
      context.push(AppRoutes.editProfileScreen);
    }
    // Other actions are placeholders for now
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

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
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Top bar ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        'Profile',
                        style: GoogleFonts.manrope(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _IconButton(
                        icon: Icons.settings_outlined,
                        onTap: () {}, // Settings placeholder
                      ),
                    ],
                  ),
                ),
              ),

              // ── Avatar + identity ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    children: [
                      // Avatar with gradient ring
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withAlpha(60),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl:
                                      'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=200',
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: AppTheme.surfaceVariantDark,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppTheme.surfaceVariantDark,
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: AppTheme.textMuted,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Edit badge
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.backgroundDark,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Maya',
                        style: GoogleFonts.manrope(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@maya',
                        style: GoogleFonts.manrope(
                          color: AppTheme.primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Collecting little moments that matter.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Edit profile pill
                      GestureDetector(
                        onTap: () {
                          context.push(AppRoutes.editProfileScreen);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariantDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.outline,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Edit Profile',
                            style: GoogleFonts.manrope(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats row ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.outline, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        _StatItem(value: '42', label: 'Memories'),
                        _VerticalDivider(),
                        _StatItem(value: '4', label: 'Circles'),
                        _VerticalDivider(),
                        _StatItem(value: '18', label: 'People'),
                      ],
                    ),
                  ),
                ),
              ),

              // ── My Memories ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _SectionHeader(
                    title: 'My Memories',
                    onSeeAll: () => context.go(AppRoutes.memoriesScreen),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 148,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _myMemories.length,
                    itemBuilder: (context, index) {
                      final m = _myMemories[index];
                      return _MemoryCard(memory: m);
                    },
                  ),
                ),
              ),

              // ── My Circles ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _SectionHeader(
                    title: 'My Circles',
                    onSeeAll: () => context.go(AppRoutes.circlesScreen),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final c = _myCircles[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _CircleRowItem(circle: c),
                  );
                }, childCount: _myCircles.length),
              ),

              // ── Activity / About ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity',
                        style: GoogleFonts.manrope(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.outline,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            _ActivityRow(
                              icon: Icons.photo_library_outlined,
                              text: '42 memories shared',
                            ),
                            const SizedBox(height: 10),
                            _ActivityRow(
                              icon: Icons.calendar_today_outlined,
                              text: 'Member since Aug 2026',
                            ),
                            const SizedBox(height: 10),
                            _ActivityRow(
                              icon: Icons.group_outlined,
                              text: 'Part of 4 circles',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Account actions ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account',
                        style: GoogleFonts.manrope(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.outline,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          children: List.generate(_accountActions.length, (
                            index,
                          ) {
                            final action = _accountActions[index];
                            final isLast = index == _accountActions.length - 1;
                            return _AccountActionRow(
                              action: action,
                              isLast: isLast,
                              onTap: () => _onAccountActionTap(action),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom padding for nav bar
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 96)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline, width: 0.8),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 18),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.8, height: 36, color: AppTheme.outline);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: GoogleFonts.manrope(
              color: AppTheme.primaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final _MemoryPreview memory;

  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: memory.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppTheme.surfaceDark),
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.surfaceDark),
            ),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xCC0A0F0D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Title + date
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    memory.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    memory.date,
                    style: GoogleFonts.manrope(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
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

class _CircleRowItem extends StatelessWidget {
  final _CircleRow circle;

  const _CircleRowItem({required this.circle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline, width: 0.8),
      ),
      child: Row(
        children: [
          // Circle avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: circle.accent.withAlpha(120),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: circle.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppTheme.surfaceVariantDark),
                errorWidget: (_, __, ___) =>
                    Container(color: AppTheme.surfaceVariantDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  circle.name,
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${circle.memberCount} members',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ActivityRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 16),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.manrope(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _AccountActionRow extends StatelessWidget {
  final _AccountAction action;
  final bool isLast;
  final VoidCallback onTap;

  const _AccountActionRow({
    required this.action,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = action.isDanger ? AppTheme.error : AppTheme.textPrimary;
    final iconColor = action.isDanger ? AppTheme.error : AppTheme.textSecondary;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isLast ? Radius.zero : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(action.icon, color: iconColor, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    action.label,
                    style: GoogleFonts.manrope(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!action.isDanger)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 0.8,
            thickness: 0.8,
            color: AppTheme.outline,
            indent: 50,
          ),
      ],
    );
  }
}
