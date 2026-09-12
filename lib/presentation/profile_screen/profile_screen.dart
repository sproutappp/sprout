import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/profile.dart';
import '../../models/circle.dart';
import '../../models/memory.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/profiles_repository.dart';
import '../../services/circles_repository.dart';
import '../../services/memories_repository.dart';
import '../../widgets/circle_action_menu.dart';
import '../memories_screen/widgets/memories_grid_widget.dart' show MemoryItem, MemoryPrivacy, MemoryType;

// ── View-model shapes ────────────────────────────────────────────────────
// Populated from real Supabase data in _load() below — no hardcoded
// instances of these anymore.

class _MemoryPreview {
  final String id;
  final String title;
  final String date;
  final String imageUrl;
  final String semanticLabel;
  final String circleName;

  const _MemoryPreview({
    required this.id,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.semanticLabel,
    required this.circleName,
  });

  factory _MemoryPreview.fromMemory(Memory m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return _MemoryPreview(
      id: m.id,
      title: m.caption?.isNotEmpty == true ? m.caption! : 'A shared memory',
      date: '${months[m.createdAt.month - 1]} ${m.createdAt.day}',
      imageUrl: m.imageUrl,
      semanticLabel: 'Shared memory photo',
      circleName: m.circleName ?? 'Circle',
    );
  }
}

class _CircleRow {
  final String id;
  final String name;
  final int memberCount;
  final String imageUrl;
  final String semanticLabel;
  final Color accent;
  final Circle sourceCircle;

  const _CircleRow({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.imageUrl,
    required this.semanticLabel,
    required this.accent,
    required this.sourceCircle,
  });

  static const _palette = [
    Color(0xFFFFB84D),
    Color(0xFF39FF8C),
    Color(0xFF00E5FF),
    Color(0xFFFF6B9D),
  ];

  factory _CircleRow.fromCircle(Circle c, int index) => _CircleRow(
    id: c.id,
    name: c.name,
    sourceCircle: c,
    memberCount: c.memberCount,
    imageUrl: c.coverImageUrl ??
        'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=120',
    semanticLabel: '${c.name} circle cover photo',
    accent: _palette[index % _palette.length],
  );
}

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

  Profile? _profile;
  List<_MemoryPreview> _myMemories = [];
  List<_CircleRow> _myCircles = [];
  bool _isLoading = true;
  String? _error;

  // Circles/memories load independently of the profile itself — a
  // failure loading either of these must never blank out the profile
  // that already loaded successfully. These only affect their own
  // section of the screen, not the top-level _error above.
  bool _circlesFailed = false;
  bool _memoriesFailed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _circlesFailed = false;
      _memoriesFailed = false;
    });

    // Step 1: the profile itself. This is the only failure that should
    // blank the whole screen — everything below degrades independently.
    Profile profile;
    try {
      final fetched = await ProfilesRepository.fetchCurrentUser();
      if (fetched == null) {
        if (!mounted) return;
        setState(() {
          _error = "Couldn't load your profile.";
          _isLoading = false;
        });
        return;
      }
      profile = fetched;
    } catch (e, st) {
      debugPrint('ProfileScreen: profile fetch failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your profile.";
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoading = false;
    });

    // Step 2: circles — independent. A failure here only clears the
    // circles section, it never touches _error/_profile.
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() {
        _myCircles = [
          for (var i = 0; i < circles.length; i++)
            _CircleRow.fromCircle(circles[i], i),
        ];
      });
    } catch (e, st) {
      debugPrint('ProfileScreen: circles fetch failed: $e\n$st');
      if (!mounted) return;
      setState(() => _circlesFailed = true);
    }

    // Step 3: memories — independent of both of the above.
    try {
      final memories = await MemoriesRepository.fetchByUploader(profile.id);
      if (!mounted) return;
      setState(() {
        _myMemories = memories.map(_MemoryPreview.fromMemory).toList();
      });
    } catch (e, st) {
      debugPrint('ProfileScreen: memories fetch failed: $e\n$st');
      if (!mounted) return;
      setState(() => _memoriesFailed = true);
    }
  }

  static String _formatMemberSince(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Sign out of both — a user may have arrived via email/
              // Google (Supabase-native) or via the phone bridge (which
              // holds both a Firebase session and a bridged Supabase
              // one). Clearing only one would leave a stale session
              // behind. FirebaseAuth.signOut() on an already-signed-out
              // instance is a safe no-op, so calling both unconditionally
              // is fine either way.
              await AuthService.signOut();
              await FirebaseAuthService.signOut();
              if (!mounted) return;
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

  Future<void> _openEditProfile() async {
    // Edit Profile can change full_name and/or avatar_url; refresh
    // regardless of what (if anything) the edit screen pops with, so
    // Profile always reflects the latest saved state on return rather
    // than waiting for some later unrelated reload.
    await context.push(AppRoutes.editProfileScreen);
    if (!mounted) return;
    await _load();
  }

  void _onAccountActionTap(_AccountAction action) {
    if (action.isDanger) {
      _showSignOutDialog();
      return;
    }
    if (action.label == 'Notifications') {
      context.push(AppRoutes.notificationsScreen);
    } else if (action.label == 'Privacy') {
      context.push(AppRoutes.privacyPolicyScreen);
    } else if (action.label == 'Settings') {
      context.push(AppRoutes.settingsScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

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

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Profile not found.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    final profile = _profile!;

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
                                child: profile.avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: profile.avatarUrl!,
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
                                      )
                                    : Container(
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
                          // Edit badge
                          GestureDetector(
                            onTap: _openEditProfile,
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
                        profile.displayName,
                        style: GoogleFonts.manrope(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Edit profile pill
                      GestureDetector(
                        onTap: _openEditProfile,
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
                        _StatItem(
                          value: '${_myMemories.length}',
                          label: 'Memories',
                        ),
                        _VerticalDivider(),
                        _StatItem(
                          value: '${_myCircles.length}',
                          label: 'Circles',
                        ),
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
              if (_memoriesFailed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      "Couldn't load memories right now.",
                      style: GoogleFonts.manrope(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else if (_myMemories.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      'No memories yet.',
                      style: GoogleFonts.manrope(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
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
                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.memoryDetailScreen,
                            extra: MemoryItem(
                              id: m.id,
                              title: m.title,
                              date: m.date,
                              imageUrl: m.imageUrl,
                              semanticLabel: m.semanticLabel,
                              circle: m.circleName,
                              circleColor: AppTheme.primaryGreen,
                              privacy: MemoryPrivacy.circle,
                              type: MemoryType.photo,
                            ),
                          ),
                          child: _MemoryCard(memory: m),
                        );
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
              if (_circlesFailed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      "Couldn't load circles right now.",
                      style: GoogleFonts.manrope(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else if (_myCircles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      "You're not part of any circles yet.",
                      style: GoogleFonts.manrope(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final c = _myCircles[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.circleDetailScreen,
                          extra: c.id,
                        ),
                        child: _CircleRowItem(circle: c, onChanged: _load),
                      ),
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
                              text: '${_myMemories.length} memories shared',
                            ),
                            const SizedBox(height: 10),
                            _ActivityRow(
                              icon: Icons.calendar_today_outlined,
                              text: 'Member since ${_formatMemberSince(profile.createdAt)}',
                            ),
                            const SizedBox(height: 10),
                            _ActivityRow(
                              icon: Icons.group_outlined,
                              text: 'Part of ${_myCircles.length} circle${_myCircles.length == 1 ? '' : 's'}',
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
  final VoidCallback? onChanged;

  const _CircleRowItem({required this.circle, this.onChanged});

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
          CircleActionMenu(
            circle: circle.sourceCircle,
            onChanged: onChanged,
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
