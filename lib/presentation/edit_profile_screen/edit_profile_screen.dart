import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

// ── EditProfileScreen ─────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  bool _isSaving = false;
  final String _avatarUrl =
      'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=400';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _nameController = TextEditingController(text: 'Maya');
    _usernameController = TextEditingController(text: '@maya');
    _bioController = TextEditingController(
      text: 'Collecting little moments that matter.',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Simulate a brief save delay for UX feedback
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSaving = false);

    // Return to Profile
    context.pop();
  }

  void _changePhoto() {
    // Photo selection affordance — shows a bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceVariantDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Photo',
              style: GoogleFonts.manrope(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _PhotoOptionRow(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 4),
            _PhotoOptionRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 4),
            _PhotoOptionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Remove current photo',
              isDestructive: true,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
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

          // Scrollable form
          Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Top bar ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariantDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.outline,
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppTheme.textPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Edit Profile',
                          style: GoogleFonts.manrope(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Avatar section ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: Column(
                      children: [
                        // Avatar with camera overlay
                        GestureDetector(
                          onTap: _changePhoto,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryGreen.withAlpha(
                                        60,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.5),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: _avatarUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: AppTheme.surfaceVariantDark,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppTheme.surfaceVariantDark,
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: AppTheme.textMuted,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Camera edit badge
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.backgroundDark,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _changePhoto,
                          child: Text(
                            'Change photo',
                            style: GoogleFonts.manrope(
                              color: AppTheme.primaryGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Form fields ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Name
                        _FieldLabel(label: 'Full Name'),
                        const SizedBox(height: 8),
                        _ProfileTextField(
                          controller: _nameController,
                          hintText: 'Your full name',
                          keyboardType: TextInputType.name,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Name cannot be empty';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Username
                        _FieldLabel(label: 'Username'),
                        const SizedBox(height: 8),
                        _ProfileTextField(
                          controller: _usernameController,
                          hintText: '@username',
                          keyboardType: TextInputType.text,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Username cannot be empty';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Bio
                        _FieldLabel(label: 'Bio'),
                        const SizedBox(height: 8),
                        _ProfileTextField(
                          controller: _bioController,
                          hintText: 'Tell your story…',
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom padding for save button
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomPadding + 100),
                ),
              ],
            ),
          ),

          // ── Save Changes button (pinned bottom) ────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomPadding + 24,
            child: GestureDetector(
              onTap: _isSaving ? null : _saveChanges,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  gradient: _isSaving ? null : AppTheme.primaryGradient,
                  color: _isSaving ? AppTheme.surfaceVariantDark : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _isSaving
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withAlpha(90),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Center(
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryGreen,
                            ),
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.manrope(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _ProfileTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.manrope(
        color: AppTheme.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: AppTheme.primaryGreen,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.manrope(
          color: AppTheme.textDisabled,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppTheme.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
      ),
    );
  }
}

class _PhotoOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _PhotoOptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.error : AppTheme.textPrimary;
    final iconColor = isDestructive ? AppTheme.error : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
