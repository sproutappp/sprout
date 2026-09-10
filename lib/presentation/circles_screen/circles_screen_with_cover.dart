import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/circle.dart';
import '../../routes/app_routes.dart';
import '../../services/circles_repository.dart';
import '../../services/notifications_repository.dart';
import '../../theme/app_theme.dart';

class CirclesScreenWithCover extends StatefulWidget {
  const CirclesScreenWithCover({super.key});

  @override
  State<CirclesScreenWithCover> createState() => _CirclesScreenWithCoverState();
}

class _CirclesScreenWithCoverState extends State<CirclesScreenWithCover> {
  static const _palette = [
    Color(0xFFFFB84D),
    Color(0xFF39FF8C),
    Color(0xFF00E5FF),
    Color(0xFFFF7EB3),
  ];

  List<Circle> _circles = [];
  bool _isLoading = true;
  String? _error;
  int _unreadMemoryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCircles();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationsRepository.fetchUnreadCircleMemoryCount();
      if (!mounted) return;
      setState(() => _unreadMemoryCount = count);
    } catch (e, st) {
      debugPrint('CirclesScreen: unread count failed: $e\n$st');
    }
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
        _circles = circles;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('CirclesScreen: fetchMyCircles failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your circles. Pull down to try again.";
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateCircle() async {
    final newCircleId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateCircleSheetWithCover(),
    );
    if (newCircleId == null) return;

    await _loadCircles();
    if (!mounted) return;
    context.push(AppRoutes.circleDetailScreen, extra: newCircleId);
  }

  void _openCircleDetail(Circle circle) {
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
        child: RefreshIndicator(
          onRefresh: _loadCircles,
          color: AppTheme.primaryGreen,
          backgroundColor: AppTheme.surfaceDark,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The people you share memories with',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
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
                      if (_circles.isNotEmpty)
                        GestureDetector(
                          onTap: _openCreateCircle,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
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
              if (_unreadMemoryCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _UnreadBanner(count: _unreadMemoryCount),
                  ),
                ),
              if (_unreadMemoryCount > 0)
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                    child: Column(
                      children: [
                        Text(
                          'No circles yet — create one to start sharing memories.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CreateCircleButton(onTap: _openCreateCircle),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: _circles.length,
                    itemBuilder: (context, index) {
                      final circle = _circles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CircleCard(
                          circle: circle,
                          accentColor: _palette[index % _palette.length],
                          onTap: () => _openCircleDetail(circle),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBanner extends StatelessWidget {
  final int count;
  const _UnreadBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withAlpha(55)),
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
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? '1 new memory across your circles'
                  : '$count new memories across your circles',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  final Circle circle;
  final Color accentColor;
  final VoidCallback onTap;

  const _CircleCard({
    required this.circle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = circle.coverImageUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withAlpha(45)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: coverUrl == null || coverUrl.isEmpty
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppTheme.surfaceVariantDark,
                      child: const Icon(
                        Icons.group_rounded,
                        size: 28,
                        color: AppTheme.textDisabled,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: coverUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
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
            const SizedBox(width: 14),
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
                  Text(
                    '${circle.memberCount} members',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      circle.description?.isNotEmpty == true
                          ? circle.description!
                          : '${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCircleButton({required this.onTap});

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
          border: Border.all(color: AppTheme.outline),
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
              child: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
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

class _CreateCircleSheetWithCover extends StatefulWidget {
  const _CreateCircleSheetWithCover();

  @override
  State<_CreateCircleSheetWithCover> createState() =>
      _CreateCircleSheetWithCoverState();
}

class _CreateCircleSheetWithCoverState
    extends State<_CreateCircleSheetWithCover> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  File? _coverFile;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _coverFile = File(picked.path));
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final coverFile = _coverFile;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a circle name.')),
      );
      return;
    }
    if (coverFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A circle cover image is required.')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final circle = await CirclesRepository.createCircle(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        coverFile: coverFile,
      );
      if (!mounted) return;
      Navigator.pop(context, circle.id);
    } catch (e, st) {
      debugPrint('CreateCircleSheet: createCircle failed: $e\n$st');
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
      child: SingleChildScrollView(
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
              'Create a Circle',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A private space for your trusted people',
              style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            _SheetLabel('Circle name'),
            const SizedBox(height: 8),
            _SheetTextField(
              controller: _nameController,
              hint: 'e.g. Family, College Friends...',
              icon: Icons.group_rounded,
            ),
            const SizedBox(height: 16),
            _SheetLabel('Description (optional)'),
            const SizedBox(height: 8),
            _SheetTextField(
              controller: _descController,
              hint: "What's this circle about?",
              icon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _SheetLabel('Circle cover *'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isCreating ? null : _pickCover,
              child: Container(
                height: 150,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outline, width: 0.8),
                ),
                child: _coverFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 34,
                            color: AppTheme.textDisabled,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select a cover image',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Required',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.textDisabled,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_coverFile!, fit: BoxFit.cover),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(170),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Change',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating || _coverFile == null ? null : _create,
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
