import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/account_deletion_service.dart';
import '../../services/settings_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;
  bool _notificationsEnabled = true;
  String _dataUsage = SettingsPreferences.dataUsageWifiAndMobile;
  bool _isLoadingPreferences = true;

  static final Uri _supportUri = Uri(
    scheme: 'mailto',
    path: 'mahesh@akshatmedia.in',
    query: 'subject=Sprout Help & Support',
  );

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final notificationsEnabled =
          await SettingsPreferences.notificationsEnabled();
      final dataUsage = await SettingsPreferences.dataUsage();

      if (!mounted) return;
      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _dataUsage = dataUsage;
        _isLoadingPreferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPreferences = false);
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final previous = _notificationsEnabled;
    setState(() => _notificationsEnabled = value);

    try {
      await SettingsPreferences.setNotificationsEnabled(value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = previous);
      _showMessage('Couldn\'t save notification preference.');
    }
  }

  Future<void> _selectDataUsage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceVariantDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  'Data Usage',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              RadioListTile<String>(
                value: SettingsPreferences.dataUsageWifiOnly,
                groupValue: _dataUsage,
                activeColor: AppTheme.primaryGreen,
                title: Text(
                  'Wi-Fi only',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Use Wi-Fi for media-heavy activity.',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
              RadioListTile<String>(
                value: SettingsPreferences.dataUsageWifiAndMobile,
                groupValue: _dataUsage,
                activeColor: AppTheme.primaryGreen,
                title: Text(
                  'Wi-Fi + Mobile Data',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Allow media activity on mobile data too.',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final previous = _dataUsage;
    setState(() => _dataUsage = selected);
    try {
      await SettingsPreferences.setDataUsage(selected);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dataUsage = previous);
      _showMessage('Couldn\'t save data usage preference.');
    }
  }

  Future<void> _openSupport() async {
    if (!await launchUrl(_supportUri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showMessage('Couldn\'t open your email app.');
    }
  }

  void _openPrivacyPolicy() {
    context.push(AppRoutes.privacyPolicyScreen);
  }

  void _openAboutSprout() {
    context.push(AppRoutes.aboutSproutScreen);
  }

  String get _dataUsageLabel => _dataUsage == SettingsPreferences.dataUsageWifiOnly
      ? 'Wi-Fi only'
      : 'Wi-Fi + Mobile Data';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surfaceVariantDark,
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariantDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.outline, width: 0.8),
        ),
        title: Text(
          'Delete Account?',
          style: GoogleFonts.manrope(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the account?',
          style: GoogleFonts.manrope(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'No',
              style: GoogleFonts.manrope(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes',
              style: GoogleFonts.manrope(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await AccountDeletionService.deleteCurrentAccount();

      if (!mounted) return;
      context.go(AppRoutes.signUpLoginScreen);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showMessage('Couldn\'t delete your account. Please try again.');
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 9),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline, width: 0.8),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, color: AppTheme.outline);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.8),
                radius: 1.2,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    topPadding > 0 ? 4 : 16,
                    20,
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Settings',
                        style: GoogleFonts.manrope(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
                    children: [
                      _sectionLabel('Preferences'),
                      _card(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            secondary: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppTheme.primaryGreen,
                            ),
                            title: Text(
                              'Notifications',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _notificationsEnabled
                                  ? 'Notifications are enabled.'
                                  : 'Notifications are turned off.',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            value: _notificationsEnabled,
                            onChanged: _isLoadingPreferences
                                ? null
                                : _setNotificationsEnabled,
                          ),
                          _divider(),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.data_usage_rounded,
                              color: AppTheme.primaryGreen,
                            ),
                            title: Text(
                              'Data Usage',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _dataUsageLabel,
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onTap: _isLoadingPreferences ? null : _selectDataUsage,
                          ),
                        ],
                      ),
                      _sectionLabel('Support'),
                      _card(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.help_outline_rounded,
                              color: AppTheme.primaryGreen,
                            ),
                            title: Text(
                              'Help & Support',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'mahesh@akshatmedia.in',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onTap: _openSupport,
                          ),
                        ],
                      ),
                      _sectionLabel('About'),
                      _card(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.primaryGreen,
                            ),
                            title: Text(
                              'About Sprout',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Version 2.0.0 (build 13)',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onTap: _openAboutSprout,
                          ),
                        ],
                      ),
                      _sectionLabel('Legal & Account'),
                      _card(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.privacy_tip_outlined,
                              color: AppTheme.primaryGreen,
                            ),
                            title: Text(
                              'Privacy Policy',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Read how Sprout handles your data.',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onTap: _openPrivacyPolicy,
                          ),
                          _divider(),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.error,
                            ),
                            title: Text(
                              'Delete Account',
                              style: GoogleFonts.manrope(
                                color: AppTheme.error,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Permanently delete your Sprout account and data.',
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                            ),
                            onTap: _isDeleting ? null : _confirmDeleteAccount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isDeleting)
            Container(
              color: Colors.black.withAlpha(90),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
