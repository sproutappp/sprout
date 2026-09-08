import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/profiles_repository.dart';
import '../theme/app_theme.dart';

/// The signed-in user's own avatar, resolved from `profiles.avatar_url`.
///
/// Used anywhere the app bar/nav shows "your" profile picture (Home,
/// Circles, Memories). Falls back to a plain person icon while loading,
/// on fetch failure, or when the user hasn't set an avatar yet — never a
/// stock photo of a stranger.
///
/// A tiny in-memory cache means only the first instance built per app
/// session actually hits the network; [refresh] can be called (e.g. after
/// editing the profile) to bust it.
class CurrentUserAvatarWidget extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const CurrentUserAvatarWidget({super.key, this.size = 36, this.onTap});

  static String? _cachedAvatarUrl;
  static bool _cacheLoaded = false;

  /// Call after the user changes their avatar so the next build re-fetches.
  static void refresh() {
    _cacheLoaded = false;
    _cachedAvatarUrl = null;
  }

  @override
  State<CurrentUserAvatarWidget> createState() =>
      _CurrentUserAvatarWidgetState();
}

class _CurrentUserAvatarWidgetState extends State<CurrentUserAvatarWidget> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    if (CurrentUserAvatarWidget._cacheLoaded) {
      _avatarUrl = CurrentUserAvatarWidget._cachedAvatarUrl;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final profile = await ProfilesRepository.fetchCurrentUser();
      CurrentUserAvatarWidget._cachedAvatarUrl = profile?.avatarUrl;
      CurrentUserAvatarWidget._cacheLoaded = true;
      if (!mounted) return;
      setState(() => _avatarUrl = profile?.avatarUrl);
    } catch (_) {
      // Silently fall back to the placeholder icon — a failed avatar
      // fetch shouldn't surface as an error in the app bar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppTheme.surfaceVariantDark,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: widget.size * 0.55,
        color: AppTheme.textMuted,
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryGreen.withAlpha(128),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: _avatarUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
        ),
      ),
    );
  }
}
