import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/profiles_repository.dart';
import '../../widgets/current_user_avatar_widget.dart';

// ── EditProfileScreen ─────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  DateTime? _dateOfBirth;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPhoto = false;
  String? _error;
  Profile? _profile;
  String? _avatarUrl;

  final _imagePicker = ImagePicker();

  // Read-only account info — not stored in `profiles`, so not part of
  // Profile/ProfilesRepository. Sourced directly from whichever auth
  // system actually owns each value (see _load()).
  String? _readOnlyEmail;
  String? _readOnlyMobile;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _nameController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await ProfilesRepository.fetchCurrentUser();
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _error = "Couldn't load your profile.";
          _isLoading = false;
        });
        return;
      }

      // Email comes from the Supabase auth user, not `profiles` — but
      // phone-OTP accounts are keyed by a synthetic
      // "<digits>@phone.sprout.invalid" address (see PhoneAuthBridge)
      // that was never a real email and would only confuse someone
      // looking at their own account info, so it's treated the same as
      // "no email on file" here rather than displayed.
      final authEmail = AuthService.currentUser?.email;
      final hasRealEmail =
          authEmail != null && !authEmail.endsWith('@phone.sprout.invalid');

      // Mobile number: only ever present for accounts that actually
      // signed in through the Firebase phone-OTP bridge. Read straight
      // from Firebase's own User object — nothing new to store, and
      // this stays a read-only display value, not something this
      // screen can edit (changing a verified phone number has to go
      // through OTP verification again, not a text field).
      final phoneNumber = FirebaseAuthService.currentUser?.phoneNumber;

      setState(() {
        _profile = profile;
        _nameController.text = profile.fullName ?? '';
        _dateOfBirth = profile.dateOfBirth;
        _avatarUrl = profile.avatarUrl;
        _readOnlyEmail = hasRealEmail ? authEmail : null;
        _readOnlyMobile = phoneNumber;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your profile.";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    String? dobWarning;
    try {
      try {
        await ProfilesRepository.updateBasicInfo(
          fullName: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          updateDateOfBirth: true,
        );
      } on PostgrestException catch (e) {
        // `date_of_birth` is a new column (see supabase/schema.sql) —
        // if the migration hasn't been run against this project yet,
        // Postgres reports it as undefined (code 42703). Don't let a
        // missing column block saving the name too; retry without it
        // and tell the person their date of birth specifically wasn't
        // saved, rather than failing the whole save silently-wrongly.
        final isMissingColumn =
            e.code == '42703' || e.message.contains('date_of_birth');
        if (!isMissingColumn) rethrow;
        await ProfilesRepository.updateBasicInfo(
          fullName: _nameController.text.trim(),
        );
        dobWarning =
            "Saved your name, but date of birth couldn't be saved yet.";
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      if (dobWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dobWarning,
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: AppTheme.textMuted,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't save your changes — try again.",
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    Navigator.of(context).pop(); // close the bottom sheet first
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isChangingPhoto = true);
      final newUrl = await ProfilesRepository.uploadAvatar(File(picked.path));
      if (!mounted) return;
      // Bust the app-bar avatar cache immediately — the source of truth
      // (profiles.avatar_url) just changed, so Home/Circles/Memories
      // should pick up the new photo on their next build, not stay
      // stale until some unrelated reload.
      CurrentUserAvatarWidget.refresh();
      setState(() {
        _avatarUrl = newUrl;
        _isChangingPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChangingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't update your photo — try again.",
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    Navigator.of(context).pop();
    setState(() => _isChangingPhoto = true);
    try {
      await ProfilesRepository.removeAvatar();
      if (!mounted) return;
      CurrentUserAvatarWidget.refresh();
      setState(() {
        _avatarUrl = null;
        _isChangingPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChangingPhoto = false);
    }
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
              onTap: () => _pickAndUploadAvatar(ImageSource.camera),
            ),
            const SizedBox(height: 4),
            _PhotoOptionRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: () => _pickAndUploadAvatar(ImageSource.gallery),
            ),
            if (_avatarUrl != null) ...[
              const SizedBox(height: 4),
              _PhotoOptionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Remove current photo',
                isDestructive: true,
                onTap: _removeAvatar,
              ),
            ],
          ],
        ),
      ),
    );
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

    if (_error != null) {
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
          child: Text(_error!, style: GoogleFonts.manrope(color: AppTheme.textMuted)),
        ),
      );
    }

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
                          onTap: _isChangingPhoto ? null : _changePhoto,
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
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _avatarUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: _avatarUrl!,
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
                                              )
                                            : Container(
                                                color: AppTheme.surfaceVariantDark,
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: AppTheme.textMuted,
                                                  size: 40,
                                                ),
                                              ),
                                        if (_isChangingPhoto)
                                          Container(
                                            color: Colors.black.withAlpha(140),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
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

                        const SizedBox(height: 24),

                        // Date of Birth — editable
                        _FieldLabel(label: 'Date of Birth'),
                        const SizedBox(height: 8),
                        _DateOfBirthField(
                          value: _dateOfBirth,
                          onTap: _pickDateOfBirth,
                        ),

                        const SizedBox(height: 24),

                        // Email — read-only. Comes from the Supabase
                        // auth user, not `profiles`; changing it isn't
                        // safe to do from this screen (it's tied to
                        // how the account signs in), so it's shown but
                        // not editable here.
                        _FieldLabel(label: 'Email Address'),
                        const SizedBox(height: 8),
                        _ReadOnlyField(
                          value: _readOnlyEmail ?? 'No email on file',
                        ),

                        const SizedBox(height: 24),

                        // Mobile — read-only. Only present for accounts
                        // that signed in via the Firebase phone-OTP
                        // bridge; changing a verified number has to go
                        // through OTP again, not a text field here.
                        _FieldLabel(label: 'Mobile Number'),
                        const SizedBox(height: 8),
                        _ReadOnlyField(
                          value: _readOnlyMobile ?? 'No mobile number linked',
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

/// Tap-to-open date picker styled to match `_ProfileTextField`.
class _DateOfBirthField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;

  const _DateOfBirthField({required this.value, required this.onTap});

  String _format(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline, width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? _format(value!) : 'Add your date of birth',
                style: GoogleFonts.manrope(
                  color: value != null
                      ? AppTheme.textPrimary
                      : AppTheme.textDisabled,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-interactive display for account fields this screen can show but
/// can't safely edit (email, mobile — see the comments where these are
/// used above for why).
class _ReadOnlyField extends StatelessWidget {
  final String value;

  const _ReadOnlyField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark.withAlpha(140),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                color: AppTheme.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: AppTheme.textMuted,
          ),
        ],
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
