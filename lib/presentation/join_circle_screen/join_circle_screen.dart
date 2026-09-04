import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/circles_repository.dart';

/// Where someone lands to redeem a circle invite. There's no real
/// OS-level deep-linking wired up yet (that needs a domain we'd have to
/// verify ownership of for Android App Links / iOS Universal Links) —
/// for now this is reached by manually pasting the link someone shared,
/// via a "Have an invite link?" entry point on the Circles screen.
class JoinCircleScreen extends StatefulWidget {
  final String? initialToken;

  const JoinCircleScreen({super.key, this.initialToken});

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  late final TextEditingController _controller;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Accepts either the full link (https://sprout.app/join/<token>) or
  /// just the raw token, pasted directly.
  String? _extractToken(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('/join/')) {
      final parts = trimmed.split('/join/');
      final token = parts.last.trim();
      return token.isEmpty ? null : token;
    }
    return trimmed;
  }

  Future<void> _join() async {
    final token = _extractToken(_controller.text);
    if (token == null) {
      setState(() => _error = 'Paste an invite link or code first.');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final circleId = await CirclesRepository.joinViaInvite(token);
      if (!mounted) return;
      // Replace so "back" doesn't return to this join screen.
      context.pushReplacement(AppRoutes.circleDetailScreen, extra: circleId);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        // The RPC's raise exception message is genuinely useful here
        // ("This invite link has expired.", etc.) — surface it directly.
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _error = "Couldn't join that circle — try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topPadding > 0 ? 8 : 20),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Join a Circle',
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste the invite link someone shared with you.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: widget.initialToken == null,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'https://sprout.app/join/...',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.textDisabled,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariantDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.paste_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _controller.text = data!.text!;
                      }
                    },
                  ),
                ),
                onSubmitted: (_) => _join(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _join,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Join Circle',
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
      ),
    );
  }
}
