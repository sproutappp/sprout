import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

// ── Mock Circles ──────────────────────────────────────────────────────────────

class _CircleOption {
  final String name;
  final Color color;
  final String emoji;

  const _CircleOption({
    required this.name,
    required this.color,
    required this.emoji,
  });
}

const List<_CircleOption> _mockCircles = [
  _CircleOption(name: 'Family', color: Color(0xFFFF8C39), emoji: '🏡'),
  _CircleOption(name: 'College Friends', color: Color(0xFF00E5FF), emoji: '🎓'),
  _CircleOption(name: 'Adventure Crew', color: Color(0xFF39FF8C), emoji: '🏕️'),
  _CircleOption(name: 'Best Friends', color: Color(0xFFB839FF), emoji: '✨'),
];

// ── Mock People ───────────────────────────────────────────────────────────────

class _PersonOption {
  final String name;
  final String avatarUrl;

  const _PersonOption({required this.name, required this.avatarUrl});
}

const List<_PersonOption> _mockPeople = [
  _PersonOption(
    name: 'Priya',
    avatarUrl:
        'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=100',
  ),
  _PersonOption(
    name: 'Arjun',
    avatarUrl:
        'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?w=100',
  ),
  _PersonOption(
    name: 'Meera',
    avatarUrl:
        'https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?w=100',
  ),
  _PersonOption(
    name: 'Rohan',
    avatarUrl:
        'https://images.pexels.com/photos/1681010/pexels-photo-1681010.jpeg?w=100',
  ),
  _PersonOption(
    name: 'Ananya',
    avatarUrl:
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?w=100',
  ),
];

// ── Privacy Option ────────────────────────────────────────────────────────────

enum _Privacy { circle, public, private }

// ── Screen ────────────────────────────────────────────────────────────────────

class CreateMemoryScreen extends StatefulWidget {
  const CreateMemoryScreen({super.key});

  @override
  State<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen>
    with SingleTickerProviderStateMixin {
  // Media
  bool _hasMedia = false;
  bool _isSaving = false;

  // Form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Privacy
  _Privacy _selectedPrivacy = _Privacy.circle;

  // Circle
  String? _selectedCircle;

  // People
  final Set<String> _taggedPeople = {};

  // Scroll
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  // Save button pulse
  late AnimationController _saveController;
  late Animation<double> _saveScale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _scrollController.addListener(
      () => setState(() => _scrollOffset = _scrollController.offset),
    );
    _saveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _saveScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _saveController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    _scrollController.dispose();
    _saveController.dispose();
    super.dispose();
  }

  void _simulateMediaPick() {
    setState(() => _hasMedia = true);
  }

  void _handleSave() async {
    await _saveController.forward();
    await _saveController.reverse();
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.1,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),

          // Scrollable content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topPadding + 64)),

              // ── Media Upload / Preview ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MediaSection(
                    hasMedia: _hasMedia,
                    onPickCamera: _simulateMediaPick,
                    onPickGallery: _simulateMediaPick,
                    onRemove: () => setState(() => _hasMedia = false),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Title ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(label: 'Memory Title'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SproutTextField(
                    controller: _titleController,
                    hint: 'Give this memory a name',
                    maxLines: 1,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Caption ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(label: 'Caption'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SproutTextField(
                    controller: _captionController,
                    hint: 'What happened?',
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Location ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LocationField(controller: _locationController),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Share With ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(label: 'Share with'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PrivacySelector(
                    selected: _selectedPrivacy,
                    onChanged: (p) => setState(() {
                      _selectedPrivacy = p;
                      if (p != _Privacy.circle) _selectedCircle = null;
                    }),
                  ),
                ),
              ),

              // ── Circle Selector (conditional) ──────────────────────────
              if (_selectedPrivacy == _Privacy.circle) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _CircleSelector(
                      circles: _mockCircles,
                      selected: _selectedCircle,
                      onChanged: (c) => setState(() => _selectedCircle = c),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Tag People ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PeopleTagSection(
                    people: _mockPeople,
                    tagged: _taggedPeople,
                    onToggle: (name) => setState(() {
                      if (_taggedPeople.contains(name)) {
                        _taggedPeople.remove(name);
                      } else {
                        _taggedPeople.add(name);
                      }
                    }),
                  ),
                ),
              ),

              // Bottom space for sticky CTA
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 100)),
            ],
          ),

          // ── Top Bar ────────────────────────────────────────────────────
          _TopBar(scrollOffset: _scrollOffset),

          // ── Sticky Save CTA ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _SaveMemoryBar(
              isSaving: _isSaving,
              scaleAnimation: _saveScale,
              onSave: _handleSave,
              bottomPadding: bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final double scrollOffset;

  const _TopBar({required this.scrollOffset});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final blurAmount = (scrollOffset / 60).clamp(0.0, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurAmount * 20,
            sigmaY: blurAmount * 20,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: AppTheme.backgroundDark.withAlpha(
              (blurAmount * 200).toInt(),
            ),
            padding: EdgeInsets.fromLTRB(8, topPadding + 8, 16, 12),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantDark.withAlpha(180),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: AppTheme.outline.withAlpha(100),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create Memory',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
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

// ── Media Section ─────────────────────────────────────────────────────────────

class _MediaSection extends StatelessWidget {
  final bool hasMedia;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  const _MediaSection({
    required this.hasMedia,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (hasMedia) {
      return _MediaPreview(onRemove: onRemove);
    }
    return _MediaUploadArea(
      onPickCamera: onPickCamera,
      onPickGallery: onPickGallery,
    );
  }
}

class _MediaUploadArea extends StatelessWidget {
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  const _MediaUploadArea({
    required this.onPickCamera,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark.withAlpha(120),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppTheme.outline.withAlpha(160), width: 1.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreenGlow,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: AppTheme.primaryGreen.withAlpha(80),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 26,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Add Photo or Video',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Capture the moment that matters',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MediaPickButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: onPickCamera,
              ),
              const SizedBox(width: 12),
              _MediaPickButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onPickGallery,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaPickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaPickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevatedDark,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppTheme.outline, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  final VoidCallback onRemove;

  const _MediaPreview({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Image.network(
            'https://images.pexels.com/photos/1261728/pexels-photo-1261728.jpeg?w=800',
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel:
                'Golden sunrise breaking over misty mountain peaks with silhouetted trees',
          ),
        ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20.0),
                bottomRight: Radius.circular(20.0),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.backgroundDark.withAlpha(200),
                ],
              ),
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: AppTheme.outline.withAlpha(120),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        // Change media button
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: AppTheme.outline.withAlpha(120),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 13,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Change',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ── Sprout Text Field ─────────────────────────────────────────────────────────

class _SproutTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputAction textInputAction;

  const _SproutTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textDisabled,
        ),
        filled: true,
        fillColor: AppTheme.surfaceVariantDark.withAlpha(140),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ── Location Field ────────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final TextEditingController controller;

  const _LocationField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Add location',
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.textDisabled,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 8),
          child: Icon(
            Icons.location_on_outlined,
            size: 18,
            color: AppTheme.textMuted,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixText: 'Optional',
        suffixStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.textDisabled,
        ),
        filled: true,
        fillColor: AppTheme.surfaceVariantDark.withAlpha(140),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ── Privacy Selector ──────────────────────────────────────────────────────────

class _PrivacySelector extends StatelessWidget {
  final _Privacy selected;
  final ValueChanged<_Privacy> onChanged;

  const _PrivacySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrivacyOption(
            icon: Icons.group_rounded,
            label: 'Circle',
            sublabel: 'Trusted group',
            isSelected: selected == _Privacy.circle,
            accentColor: AppTheme.primaryGreen,
            onTap: () => onChanged(_Privacy.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrivacyOption(
            icon: Icons.public_rounded,
            label: 'Public',
            sublabel: 'Everyone',
            isSelected: selected == _Privacy.public,
            accentColor: AppTheme.cyanAccent,
            onTap: () => onChanged(_Privacy.public),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrivacyOption(
            icon: Icons.lock_outline_rounded,
            label: 'Private',
            sublabel: 'Only you',
            isSelected: selected == _Privacy.private,
            accentColor: const Color(0xFFB839FF),
            onTap: () => onChanged(_Privacy.private),
          ),
        ),
      ],
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withAlpha(28)
              : AppTheme.surfaceVariantDark.withAlpha(120),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: isSelected ? accentColor.withAlpha(160) : AppTheme.outline,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accentColor : AppTheme.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? accentColor : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle Selector ───────────────────────────────────────────────────────────

class _CircleSelector extends StatelessWidget {
  final List<_CircleOption> circles;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _CircleSelector({
    required this.circles,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Circle',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: circles.map((circle) {
            final isSelected = selected == circle.name;
            return GestureDetector(
              onTap: () => onChanged(circle.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? circle.color.withAlpha(30)
                      : AppTheme.surfaceVariantDark.withAlpha(120),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isSelected
                        ? circle.color.withAlpha(180)
                        : AppTheme.outline,
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(circle.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      circle.name,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? circle.color
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: circle.color,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── People Tag Section ────────────────────────────────────────────────────────

class _PeopleTagSection extends StatelessWidget {
  final List<_PersonOption> people;
  final Set<String> tagged;
  final ValueChanged<String> onToggle;

  const _PeopleTagSection({
    required this.people,
    required this.tagged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tag People',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantDark,
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDisabled,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = people[index];
              final isTagged = tagged.contains(person.name);
              return GestureDetector(
                onTap: () => onToggle(person.name),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: isTagged
                                  ? AppTheme.primaryGreen
                                  : AppTheme.outline.withAlpha(100),
                              width: isTagged ? 2.0 : 1.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              person.avatarUrl,
                              fit: BoxFit.cover,
                              semanticLabel: '${person.name} profile photo',
                            ),
                          ),
                        ),
                        if (isTagged)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      person.name,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isTagged
                            ? AppTheme.primaryGreen
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Save Memory Bar ───────────────────────────────────────────────────────────

class _SaveMemoryBar extends StatelessWidget {
  final bool isSaving;
  final Animation<double> scaleAnimation;
  final VoidCallback onSave;
  final double bottomPadding;

  const _SaveMemoryBar({
    required this.isSaving,
    required this.scaleAnimation,
    required this.onSave,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withAlpha(200),
            border: Border(
              top: BorderSide(
                color: AppTheme.outline.withAlpha(100),
                width: 0.8,
              ),
            ),
          ),
          child: ScaleTransition(
            scale: scaleAnimation,
            child: GestureDetector(
              onTap: isSaving ? null : onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  gradient: isSaving
                      ? LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withAlpha(120),
                            AppTheme.cyanAccent.withAlpha(120),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: isSaving
                      ? []
                      : [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withAlpha(90),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Center(
                  child: isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black.withAlpha(180),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Saving...',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withAlpha(180),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_add_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Save Memory',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
