import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/circle.dart';
import '../../services/circles_repository.dart';

// ── Circle card view-model ──────────────────────────────────────────────────
// Wraps the real `Circle` model with a few presentation-only touches
// (accent color, fallback cover image) that don't belong in the data model.

class _CircleData {
  final String id;
  final String name;
  final int memberCount;
  final String activityLabel;
  final String imageUrl;
  final String imageSemanticLabel;
  final Color accentColor;

  const _CircleData({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.activityLabel,
    required this.imageUrl,
    required this.imageSemanticLabel,
  }) : accentColor = AppTheme.primaryGreen;

  factory _CircleData.fromCircle(Circle circle, int paletteIndex) {
    const palette = [
      Color(0xFFFFB84D),
      Color(0xFF39FF8C),
      Color(0xFF00E5FF),
      Color(0xFFFF7EB3),
    ];
    return _CircleData(
      id: circle.id,
      name: circle.name,
      memberCount: circle.memberCount,
      activityLabel: circle.description?.isNotEmpty == true
          ? circle.description!
          : '${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'}',
      imageUrl: circle.coverImageUrl ??
          'https://images.pexels.com/photos/1128318/pexels-photo-1128318.jpeg?w=400',
      imageSemanticLabel: '${circle.name} circle cover photo',
    )._withAccent(palette[paletteIndex % palette.length]);
  }

  _CircleData _withAccent(Color color) => _CircleData._(
        id: id,
        name: name,
        memberCount: memberCount,
        activityLabel: activityLabel,
        imageUrl: imageUrl,
        imageSemanticLabel: imageSemanticLabel,
        accentColor: color,
      );

  const _CircleData._({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.activityLabel,
    required this.imageUrl,
    required this.imageSemanticLabel,
    required this.accentColor,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  List<_CircleData> _circles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCircles();
  }

  Future<void> _loadCircles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() {
        _circles = [
          for (var i = 0; i < circles.length; i++)
            _CircleData.fromCircle(circles[i], i),
        ];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your circles. Pull down to try again.";
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateCircle() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateCircleSheet(),
    );
    if (created == true) {
      _loadCircles();
    }
  }

  void _openCircleDetail(_CircleData circle) {
    context.push(AppRoutes.circleDetailScreen, extra: circle.id);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.3,
            colors: [Color(0xFF0D1A10), Color(0xFF0A0F0D)],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Circles',
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The people you share memories with',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () =>
                                context.push(AppRoutes.joinCircleScreen),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  size: 14,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Have an invite link? Join a circle',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                          color: AppTheme.surfaceVariantDark.withAlpha(179),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.outline,
                            width: 0.5,
                          ),
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
                    const SizedBox(width: 8),
                    // Create circle button
                    GestureDetector(
                      onTap: _openCreateCircle,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withAlpha(60),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── New memories banner ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NewMemoriesBanner(onTap: () {}),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Circle cards list ────────────────────────────────────────
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 60,
                  ),
                  child: Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              )
            else if (_circles.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 60,
                  ),
                  child: Center(
                    child: Text(
                      'No circles yet — create one to start sharing memories.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final circle = _circles[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CircleCard(
                        circle: circle,
                        onTap: () => _openCircleDetail(circle),
                      ),
                    );
                  }, childCount: _circles.length),
                ),
              ),

            // ── Create Circle CTA ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _CreateCircleCTA(onTap: _openCreateCircle),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ── New Memories Banner ───────────────────────────────────────────────────────

class _NewMemoriesBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _NewMemoriesBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGreen.withAlpha(22),
              AppTheme.cyanAccent.withAlpha(14),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGreen.withAlpha(60),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
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
                    '3 new memories across your circles',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to catch up',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle Card ───────────────────────────────────────────────────────────────

class _CircleCard extends StatelessWidget {
  final _CircleData circle;
  final VoidCallback onTap;

  const _CircleCard({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: circle.accentColor.withAlpha(45),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Group image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: circle.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 64,
                        height: 64,
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.group_rounded,
                          size: 28,
                          color: AppTheme.textDisabled,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.group_rounded,
                          size: 28,
                          color: AppTheme.textDisabled,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_rounded,
                          size: 12,
                          color: AppTheme.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${circle.memberCount} members',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Activity label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: circle.accentColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: circle.accentColor.withAlpha(50),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        circle.activityLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: circle.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create Circle CTA ─────────────────────────────────────────────────────────

class _CreateCircleCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateCircleCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outline, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Create Circle',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Circle Bottom Sheet ────────────────────────────────────────────────

class _CreateCircleSheet extends StatefulWidget {
  const _CreateCircleSheet();

  @override
  State<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<_CreateCircleSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  void _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isCreating = true);

    try {
      await CirclesRepository.createCircle(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$name" circle created!',
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't create circle — try again.",
            style: GoogleFonts.manrope(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        bottomPadding + keyboardHeight + 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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

          // Title
          Text(
            'Create a Circle',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A private space for your trusted people',
            style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted),
          ),

          const SizedBox(height: 24),

          // Circle name
          _SheetLabel('Circle name'),
          const SizedBox(height: 8),
          _SheetTextField(
            controller: _nameController,
            hint: 'e.g. Family, College Friends...',
            icon: Icons.group_rounded,
          ),

          const SizedBox(height: 16),

          // Description
          _SheetLabel('Description (optional)'),
          const SizedBox(height: 8),
          _SheetTextField(
            controller: _descController,
            hint: 'What\'s this circle about?',
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),

          const SizedBox(height: 16),

          // Add people
          _SheetLabel('Add people'),
          const SizedBox(height: 8),
          _SheetTextField(
            controller: _peopleController,
            hint: 'Search by name or username...',
            icon: Icons.person_add_rounded,
          ),

          const SizedBox(height: 28),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppTheme.primaryGreen.withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Create Circle',
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

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _SheetTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, maxLines > 1 ? 14 : 0, 0, 0),
            child: Icon(icon, size: 18, color: AppTheme.textDisabled),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.textDisabled,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
