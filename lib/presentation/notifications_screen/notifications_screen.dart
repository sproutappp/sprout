import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../presentation/memories_screen/widgets/memories_grid_widget.dart';

// ── Notification types ────────────────────────────────────────────────────────

enum _NotifType {
  reaction,
  comment,
  circleMemory,
  circleInvite,
  circleJoin,
  mention,
}

enum _NotifGroup { today, earlier }

class _NotifItem {
  final String id;
  final _NotifType type;
  final _NotifGroup group;
  final String personName;
  final String personAvatarUrl;
  final String message;
  final String timeAgo;
  bool isRead;

  // Optional navigation targets
  final String? memoryId;
  final String? circleId;
  final String? memberId;

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
    this.memberId,
  });
}

final List<_NotifItem> _mockNotifications = [
  _NotifItem(
    id: 'n_001',
    type: _NotifType.reaction,
    group: _NotifGroup.today,
    personName: 'Priya',
    personAvatarUrl:
        'https://images.pexels.com/photos/3763188/pexels-photo-3763188.jpeg?w=100',
    message: 'Priya reacted ✨ to your memory "Sunrise at Mullayanagiri"',
    timeAgo: '2 min ago',
    isRead: false,
    memoryId: 'm01',
    memberId: 'priya',
  ),
  _NotifItem(
    id: 'n_002',
    type: _NotifType.comment,
    group: _NotifGroup.today,
    personName: 'Kiran',
    personAvatarUrl:
        'https://images.pexels.com/photos/2379005/pexels-photo-2379005.jpeg?w=100',
    message: 'Kiran commented on "Sunrise at Mullayanagiri"',
    timeAgo: '1 hour ago',
    isRead: false,
    memoryId: 'm01',
    memberId: 'kiran',
  ),
  _NotifItem(
    id: 'n_003',
    type: _NotifType.circleMemory,
    group: _NotifGroup.today,
    personName: 'Arjun',
    personAvatarUrl:
        'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?w=100',
    message: 'Arjun added a new memory to Adventure Crew',
    timeAgo: '3 hours ago',
    isRead: false,
    circleId: 'c_003',
    memberId: 'arjun',
  ),
  _NotifItem(
    id: 'n_004',
    type: _NotifType.circleInvite,
    group: _NotifGroup.today,
    personName: 'Priya',
    personAvatarUrl:
        'https://images.pexels.com/photos/3763188/pexels-photo-3763188.jpeg?w=100',
    message: 'Priya invited you to join "College Friends"',
    timeAgo: '5 hours ago',
    isRead: true,
    circleId: 'c_002',
    memberId: 'priya',
  ),
  _NotifItem(
    id: 'n_005',
    type: _NotifType.reaction,
    group: _NotifGroup.today,
    personName: 'Meera',
    personAvatarUrl:
        'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=100',
    message: 'Meera reacted 🌿 to your memory "Late night chai"',
    timeAgo: '8 hours ago',
    isRead: true,
    memoryId: 'm03',
    memberId: 'meera',
  ),
  _NotifItem(
    id: 'n_006',
    type: _NotifType.circleJoin,
    group: _NotifGroup.earlier,
    personName: 'Rohan',
    personAvatarUrl:
        'https://images.pexels.com/photos/614810/pexels-photo-614810.jpeg?w=100',
    message: 'Rohan joined your Circle "Adventure Crew"',
    timeAgo: '1 day ago',
    isRead: true,
    circleId: 'c_003',
    memberId: 'rohan',
  ),
  _NotifItem(
    id: 'n_007',
    type: _NotifType.mention,
    group: _NotifGroup.earlier,
    personName: 'Kiran',
    personAvatarUrl:
        'https://images.pexels.com/photos/2379005/pexels-photo-2379005.jpeg?w=100',
    message: 'Kiran mentioned you in a comment on "Monsoon drive to Coorg"',
    timeAgo: '1 day ago',
    isRead: true,
    memoryId: 'm04',
    memberId: 'kiran',
  ),
  _NotifItem(
    id: 'n_008',
    type: _NotifType.comment,
    group: _NotifGroup.earlier,
    personName: 'Arjun',
    personAvatarUrl:
        'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?w=100',
    message: 'Arjun commented on "Grandma\'s 80th birthday"',
    timeAgo: '2 days ago',
    isRead: true,
    memoryId: 'm02',
    memberId: 'arjun',
  ),
  _NotifItem(
    id: 'n_009',
    type: _NotifType.circleMemory,
    group: _NotifGroup.earlier,
    personName: 'Priya',
    personAvatarUrl:
        'https://images.pexels.com/photos/3763188/pexels-photo-3763188.jpeg?w=100',
    message: 'Priya added a new memory to Family',
    timeAgo: '3 days ago',
    isRead: true,
    circleId: 'c_001',
    memberId: 'priya',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<_NotifItem> _notifications;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _notifications = _mockNotifications
        .map(
          (n) => _NotifItem(
            id: n.id,
            type: n.type,
            group: n.group,
            personName: n.personName,
            personAvatarUrl: n.personAvatarUrl,
            message: n.message,
            timeAgo: n.timeAgo,
            isRead: n.isRead,
            memoryId: n.memoryId,
            circleId: n.circleId,
            memberId: n.memberId,
          ),
        )
        .toList();
  }

  void _markRead(String id) {
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) _notifications[idx].isRead = true;
    });
  }

  void _handleTap(_NotifItem notif) {
    _markRead(notif.id);

    if (notif.memoryId != null) {
      final memory = allMemories.firstWhere(
        (m) => m.id == notif.memoryId,
        orElse: () => allMemories[0],
      );
      context.push(AppRoutes.memoryDetailScreen, extra: memory);
    } else if (notif.circleId != null) {
      context.push(AppRoutes.circleDetailScreen, extra: notif.circleId);
    } else if (notif.memberId != null) {
      context.push(
        AppRoutes.memberProfileScreen,
        extra: {
          'memberId': notif.memberId,
          'memberName': notif.personName,
          'memberAvatarUrl': notif.personAvatarUrl,
        },
      );
    }
  }

  void _handleAvatarTap(_NotifItem notif) {
    _markRead(notif.id);
    context.push(
      AppRoutes.memberProfileScreen,
      extra: {
        'memberId': notif.memberId,
        'memberName': notif.personName,
        'memberAvatarUrl': notif.personAvatarUrl,
      },
    );
  }

  IconData _iconForType(_NotifType type) {
    switch (type) {
      case _NotifType.reaction:
        return Icons.favorite_rounded;
      case _NotifType.comment:
        return Icons.chat_bubble_rounded;
      case _NotifType.circleMemory:
        return Icons.photo_rounded;
      case _NotifType.circleInvite:
        return Icons.group_add_rounded;
      case _NotifType.circleJoin:
        return Icons.group_rounded;
      case _NotifType.mention:
        return Icons.alternate_email_rounded;
    }
  }

  Color _colorForType(_NotifType type) {
    switch (type) {
      case _NotifType.reaction:
        return const Color(0xFFFF6B8A);
      case _NotifType.comment:
        return AppTheme.cyanAccent;
      case _NotifType.circleMemory:
        return AppTheme.primaryGreen;
      case _NotifType.circleInvite:
        return const Color(0xFFB839FF);
      case _NotifType.circleJoin:
        return const Color(0xFFFF8C39);
      case _NotifType.mention:
        return AppTheme.cyanAccent;
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
                      onAvatarTap: () => _handleAvatarTap(notif),
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
                      onAvatarTap: () => _handleAvatarTap(notif),
                    );
                  }, childCount: earlierNotifs.length),
                ),
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
                      child: CachedNetworkImage(
                        imageUrl: n.personAvatarUrl,
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
