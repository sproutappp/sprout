import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/notification.dart';
import '../../services/notifications_repository.dart';
import '../../services/memories_repository.dart';
import '../../presentation/memories_screen/widgets/memories_grid_widget.dart';

// ── Notification types ────────────────────────────────────────────────────
// Only circleMemory and circleJoin are backed by real triggers right now.
// Reaction/comment/mention notifications aren't buildable yet — there are
// no reactions/comments tables — so they're intentionally not represented.

enum _NotifGroup { today, earlier }

class _NotifItem {
  final String id;
  final AppNotificationType type;
  final _NotifGroup group;
  final String personName;
  final String? personAvatarUrl;
  final String message;
  final String timeAgo;
  bool isRead;
  final String? memoryId;
  final String? circleId;

  _NotifItem({
    required this.id,
    required this.type,
    required this.group,
    required this.personName,
    required this.personAvatarUrl,
    required this.message,
    required this.timeAgo,
    this.isRead = false,
    this.memoryId,
    this.circleId,
  });

  static _NotifGroup _groupFor(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return isToday ? _NotifGroup.today : _NotifGroup.earlier;
  }

  static String _timeAgoFor(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  factory _NotifItem.fromAppNotification(AppNotification n) {
    return _NotifItem(
      id: n.id,
      type: n.type,
      group: _groupFor(n.createdAt),
      personName: n.actor.displayName,
      personAvatarUrl: n.actor.avatarUrl,
      message: n.message,
      timeAgo: _timeAgoFor(n.createdAt),
      isRead: n.isRead,
      memoryId: n.memoryId,
      circleId: n.circleId,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_NotifItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notifs = await NotificationsRepository.fetchForUser();
      if (!mounted) return;
      setState(() {
        _notifications = notifs.map(_NotifItem.fromAppNotification).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load notifications.";
        _isLoading = false;
      });
    }
  }

  void _markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    setState(() => _notifications[idx].isRead = true);
    NotificationsRepository.markAsRead(id); // fire-and-forget, UI already updated
  }

  Future<void> _handleTap(_NotifItem notif) async {
    _markRead(notif.id);

    if (notif.memoryId != null) {
      final memory = await MemoriesRepository.fetchById(notif.memoryId!);
      if (!mounted) return;
      if (memory == null) return; // deleted since the notification fired
      final item = MemoryItem(
        id: memory.id,
        title: memory.caption?.isNotEmpty == true
            ? memory.caption!
            : 'A shared memory',
        date: '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}',
        imageUrl: memory.imageUrl,
        semanticLabel: 'Shared memory photo',
        circle: memory.circleName ?? 'Circle',
        circleColor: AppTheme.primaryGreen,
        privacy: MemoryPrivacy.circle,
        type: MemoryType.photo,
      );
      context.push(AppRoutes.memoryDetailScreen, extra: item);
    } else if (notif.circleId != null) {
      context.push(AppRoutes.circleDetailScreen, extra: notif.circleId);
    }
  }

  IconData _iconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.circleMemory:
        return Icons.photo_rounded;
      case AppNotificationType.circleJoin:
        return Icons.group_rounded;
    }
  }

  Color _colorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.circleMemory:
        return AppTheme.primaryGreen;
      case AppNotificationType.circleJoin:
        return const Color(0xFFFF8C39);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    final todayNotifs = _notifications
        .where((n) => n.group == _NotifGroup.today)
        .toList();
    final earlierNotifs = _notifications
        .where((n) => n.group == _NotifGroup.earlier)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.0,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),

          // Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => context.pop(),
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
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (unreadCount > 0)
                              Text(
                                '$unreadCount unread',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Mark all read
                      if (unreadCount > 0)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              for (final n in _notifications) {
                                n.isRead = true;
                              }
                            });
                            NotificationsRepository.markAllAsRead();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreenGlow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryGreen.withAlpha(77),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
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
                      vertical: 40,
                    ),
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                )
              else if (_notifications.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Center(
                      child: Text(
                        'No notifications yet.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                )
              else ...[
              // ── Today group ──────────────────────────────────────────────
              if (todayNotifs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final notif = todayNotifs[index];
                    return _NotifRow(
                      notif: notif,
                      iconData: _iconForType(notif.type),
                      iconColor: _colorForType(notif.type),
                      onTap: () => _handleTap(notif),
                      onAvatarTap: () => _handleTap(notif),
                    );
                  }, childCount: todayNotifs.length),
                ),
              ],

              // ── Earlier group ────────────────────────────────────────────
              if (earlierNotifs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Text(
                      'Earlier',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final notif = earlierNotifs[index];
                    return _NotifRow(
                      notif: notif,
                      iconData: _iconForType(notif.type),
                      iconColor: _colorForType(notif.type),
                      onTap: () => _handleTap(notif),
                      onAvatarTap: () => _handleTap(notif),
                    );
                  }, childCount: earlierNotifs.length),
                ),
              ],
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Notification Row ──────────────────────────────────────────────────────────

class _NotifRow extends StatefulWidget {
  final _NotifItem notif;
  final IconData iconData;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  const _NotifRow({
    required this.notif,
    required this.iconData,
    required this.iconColor,
    required this.onTap,
    required this.onAvatarTap,
  });

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notif;
    final isUnread = !n.isRead;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.surfaceElevatedDark
              : isUnread
              ? AppTheme.primaryGreenGlow.withAlpha(120)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppTheme.primaryGreen.withAlpha(60)
                : AppTheme.outline,
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with type icon badge
            GestureDetector(
              onTap: widget.onAvatarTap,
              child: Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUnread
                            ? AppTheme.primaryGreen.withAlpha(128)
                            : AppTheme.outline,
                        width: isUnread ? 1.5 : 1.0,
                      ),
                    ),
                    child: ClipOval(
                      child: n.personAvatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: n.personAvatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppTheme.surfaceVariantDark),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.surfaceVariantDark,
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 22,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.surfaceVariantDark,
                              child: const Icon(
                                Icons.person_rounded,
                                size: 22,
                                color: AppTheme.textMuted,
                              ),
                            ),
                    ),
                  ),
                  // Type icon badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: widget.iconColor.withAlpha(230),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.backgroundDark,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        widget.iconData,
                        size: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Message + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    n.timeAgo,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isUnread
                          ? AppTheme.primaryGreen
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Unread dot
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withAlpha(102),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
