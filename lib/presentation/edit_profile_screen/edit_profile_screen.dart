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

  // Which identity is "primary" (the one actually used to sign in) vs.
  // "linked" (added afterwards, editable here) depends on how this
  // account authenticated — see _load() for the exact detection.
  bool _isPhonePrimary = false;
  String? _linkedMobileNumber;

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
      // that was never a real email. Whether that's the *current* email
      // is also exactly the signal for which identity is "primary":
      // a synthetic email means this account signed in via phone OTP
      // (isPhonePrimary), a real one means Google/email.
      final authEmail = AuthService.currentUser?.email;
      final hasRealEmail =
          authEmail != null && !authEmail.endsWith('@phone.sprout.invalid');
      final isPhonePrimary = !hasRealEmail;

      // Mobile number: for a phone-primary account, straight from
      // Firebase's own User object — that number IS this account's
      // verified identity. For a Google/email-primary account, whatever
      // (if anything) they've separately linked via linkMobileNumber.
      final firebasePhone = FirebaseAuthService.currentUser?.phoneNumber;
      final linkedMobile = isPhonePrimary
          ? firebasePhone
          : await ProfilesRepository.fetchLinkedMobileNumber();

      setState(() {
        _profile = profile;
        _nameController.text = profile.fullName ?? '';
        _dateOfBirth = profile.dateOfBirth;
        _avatarUrl = profile.avatarUrl;
        _readOnlyEmail = hasRealEmail ? authEmail : null;
        _readOnlyMobile = firebasePhone;
        _isPhonePrimary = isPhonePrimary;
        _linkedMobileNumber = linkedMobile;
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

  Future<void> _openLinkEmail() async {
    final linked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EmailLinkSheet(),
    );
    if (linked == true) _load();
  }

  Future<void> _openLinkMobile() async {
    final linked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobileLinkSheet(),
    );
    if (linked == true) _load();
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

                        // Email: locked for a Google/email-primary
                        // account (it's the sign-in identity itself).
                        // For a phone-primary account it's editable
                        // until one is linked, then locked too.
                        _FieldLabel(label: 'Email Address'),
                        const SizedBox(height: 8),
                        if (!_isPhonePrimary || _readOnlyEmail != null)
                          _ReadOnlyField(
                            value: _readOnlyEmail ?? 'No email on file',
                          )
                        else
                          _LinkableField(
                            hint: 'Add an email address',
                            onTap: _openLinkEmail,
                          ),

                        const SizedBox(height: 24),

                        // Mobile: locked for a phone-primary account
                        // (it's the verified sign-in identity itself).
                        // For a Google/email-primary account it's
                        // editable until one is linked (via real
                        // Firebase verification), then locked too.
                        _FieldLabel(label: 'Mobile Number'),
                        const SizedBox(height: 8),
                        if (_isPhonePrimary)
                          _ReadOnlyField(
                            value: _readOnlyMobile ?? 'No mobile number linked',
                          )
                        else if (_linkedMobileNumber != null)
                          _ReadOnlyField(value: _linkedMobileNumber!)
                        else
                          _LinkableField(
                            hint: 'Add a mobile number',
                            onTap: _openLinkMobile,
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

/// Tappable prompt for an account field that's currently unset but CAN
/// be added (as opposed to `_ReadOnlyField`, which never can). Opens the
/// relevant verification sheet on tap.
class _LinkableField extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;

  const _LinkableField({required this.hint, required this.onTap});

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
          border: Border.all(
            color: AppTheme.primaryGreen.withAlpha(130),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.manrope(
                  color: AppTheme.primaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}

/// Links a new email to a phone-primary account via Supabase's native
/// email-change flow (ProfilesRepository.linkEmail) — sends a
/// confirmation link; the field only becomes "linked" once it's clicked.
class _EmailLinkSheet extends StatefulWidget {
  const _EmailLinkSheet();

  @override
  State<_EmailLinkSheet> createState() => _EmailLinkSheetState();
}

class _EmailLinkSheetState extends State<_EmailLinkSheet> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  bool _sent = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ProfilesRepository.linkEmail(email);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = "Couldn't send confirmation — try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LinkSheetScaffold(
      title: 'Add an email address',
      child: _sent
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "We've sent a confirmation link to "
                "${_emailController.text.trim()}. It'll show here as "
                'linked once confirmed.',
                style: GoogleFonts.manrope(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.manrope(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: GoogleFonts.manrope(color: AppTheme.textDisabled),
                    filled: true,
                    fillColor: AppTheme.surfaceVariantDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.manrope(color: AppTheme.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                _LinkSheetButton(
                  label: 'Send confirmation link',
                  isLoading: _isSubmitting,
                  onTap: _submit,
                ),
              ],
            ),
    );
  }
}

/// Links a new mobile number to a Google/email-primary account. Requires
/// genuine Firebase OTP verification first (FirebaseAuthService) — only
/// once that succeeds does this call ProfilesRepository.linkMobileNumber.
/// Deliberately does NOT go through PhoneAuthBridge.completeSignIn: that
/// would create/switch to a different Supabase session instead of
/// linking the number to the one already signed in.
class _MobileLinkSheet extends StatefulWidget {
  const _MobileLinkSheet();

  @override
  State<_MobileLinkSheet> createState() => _MobileLinkSheetState();
}

class _MobileLinkSheetState extends State<_MobileLinkSheet> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  String? _e164Phone;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _sendCode() async {
    var phone = _phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(() => _error = 'Enter your number in international format, e.g. +919876543210.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final taken = await ProfilesRepository.isMobileNumberTaken(phone);
      if (taken) {
        setState(() {
          _isSubmitting = false;
          _error = 'This mobile number is already linked to an account.';
        });
        return;
      }

      await FirebaseAuthService.sendOtp(
        phoneNumber: phone,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _e164Phone = phone;
            _isSubmitting = false;
          });
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _error = e.message ?? "Couldn't send the code — try again.";
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = "Couldn't send the code — try again.";
      });
    }
  }

  Future<void> _verifyAndLink() async {
    final code = _codeController.text.trim();
    if (_verificationId == null || code.isEmpty || _e164Phone == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await FirebaseAuthService.verifyOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await ProfilesRepository.linkMobileNumber(_e164Phone!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Incorrect code — try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LinkSheetScaffold(
      title: 'Add a mobile number',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneController,
            enabled: _verificationId == null,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.manrope(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: '+919876543210',
              hintStyle: GoogleFonts.manrope(color: AppTheme.textDisabled),
              filled: true,
              fillColor: AppTheme.surfaceVariantDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_verificationId != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.manrope(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '6-digit code',
                hintStyle: GoogleFonts.manrope(color: AppTheme.textDisabled),
                filled: true,
                fillColor: AppTheme.surfaceVariantDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.manrope(color: AppTheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          _LinkSheetButton(
            label: _verificationId == null ? 'Send code' : 'Verify & link',
            isLoading: _isSubmitting,
            onTap: _verificationId == null ? _sendCode : _verifyAndLink,
          ),
        ],
      ),
    );
  }
}

class _LinkSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _LinkSheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LinkSheetButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _LinkSheetButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.manrope(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
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
