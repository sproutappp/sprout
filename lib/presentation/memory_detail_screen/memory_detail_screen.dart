import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../presentation/memories_screen/widgets/memories_grid_widget.dart';
import '../../routes/app_routes.dart';
import '../../models/comment.dart';
import '../../services/reactions_repository.dart';
import '../../services/comments_repository.dart';

// ── Sample detail data ────────────────────────────────────────────────────────

class _TaggedPerson {
  final String name;
  final String avatarUrl;
  final String semanticLabel;

  const _TaggedPerson({
    required this.name,
    required this.avatarUrl,
    required this.semanticLabel,
  });
}

class MemoryDetailData {
  final MemoryItem memory;
  final String caption;
  final String location;
  final List<_TaggedPerson> taggedPeople;

  const MemoryDetailData({
    required this.memory,
    required this.caption,
    required this.location,
    required this.taggedPeople,
  });
}

// The memory's real caption is already carried on MemoryItem.title (set
// when the memory was created) — no generic filler text. There's no
// location or people-tagging data in the schema yet, so those are left
// empty rather than faked; the UI already hides empty sections.
MemoryDetailData _buildFallback(MemoryItem m) => MemoryDetailData(
  memory: m,
  caption: m.title,
  location: '',
  taggedPeople: const [],
);

// ── Screen ────────────────────────────────────────────────────────────────────

class MemoryDetailScreen extends StatefulWidget {
  final MemoryItem memory;

  const MemoryDetailScreen({super.key, required this.memory});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late final MemoryDetailData _detail;
  bool _isVideoPlaying = false;
  bool _menuOpen = false;
  late AnimationController _heroFadeController;
  late Animation<double> _heroFadeAnim;

  // Reactions/comments load in the background — the photo/caption render
  // immediately from widget.memory, these pop in shortly after.
  ReactionSummary _reactions = ReactionSummary.empty;
  List<MemoryComment> _comments = [];
  bool _isLoadingSocial = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _detail = _buildFallback(widget.memory);
    _heroFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _heroFadeAnim = CurvedAnimation(
      parent: _heroFadeController,
      curve: Curves.easeOutCubic,
    );
    _loadSocial();
  }

  Future<void> _loadSocial() async {
    try {
      final reactions = await ReactionsRepository.fetchSummary(widget.memory.id);
      final comments = await CommentsRepository.fetchForMemory(widget.memory.id);
      if (!mounted) return;
      setState(() {
        _reactions = reactions;
        _comments = comments;
        _isLoadingSocial = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSocial = false);
    }
  }

  Future<void> _onReactionTap(String emoji) async {
    final wasMine = _reactions.myEmoji == emoji;
    // Optimistic update — feels instant, corrected on failure.
    final previous = _reactions;
    setState(() {
      final counts = Map<String, int>.from(_reactions.counts);
      if (_reactions.myEmoji != null) {
        counts[_reactions.myEmoji!] =
            (counts[_reactions.myEmoji!] ?? 1) - 1;
      }
      if (!wasMine) {
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
      counts.removeWhere((_, v) => v <= 0);
      _reactions = ReactionSummary(
        counts: counts,
        myEmoji: wasMine ? null : emoji,
      );
    });

    try {
      if (wasMine) {
        await ReactionsRepository.removeReaction(widget.memory.id);
      } else {
        await ReactionsRepository.setReaction(widget.memory.id, emoji);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _reactions = previous); // revert on failure
    }
  }

  Future<void> _onCommentPosted(String text) async {
    try {
      final comment = await CommentsRepository.addComment(
        memoryId: widget.memory.id,
        body: text,
      );
      if (!mounted) return;
      setState(() => _comments = [..._comments, comment]);
    } catch (_) {
      if (!mounted) return;
      _showSnack("Couldn't post comment — try again.");
    }
  }

  @override
  void dispose() {
    _heroFadeController.dispose();
    super.dispose();
  }

  void _showMenu(BuildContext context) {
    setState(() => _menuOpen = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemoryMenuSheet(
        onEdit: () {
          Navigator.pop(context);
          _showSnack('Edit Memory coming soon');
        },
        onDelete: () {
          Navigator.pop(context);
          _showDeleteConfirm(context);
        },
        onShare: () {
          Navigator.pop(context);
          _showSnack('Sharing options coming soon');
        },
      ),
    ).whenComplete(() => setState(() => _menuOpen = false));
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DeleteConfirmDialog(
        onConfirm: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.2,
                colors: [Color(0xFF0D1A10), Color(0xFF0A0F0D)],
              ),
            ),
          ),

          // Scrollable content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero media ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _heroFadeAnim,
                  child: _HeroMedia(
                    memory: widget.memory,
                    isPlaying: _isVideoPlaying,
                    onPlayTap: () =>
                        setState(() => _isVideoPlaying = !_isVideoPlaying),
                    topPadding: topPadding,
                  ),
                ),
              ),

              // ── Memory info ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.memory.title,
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Date + location row
                      _MetaRow(
                        date: widget.memory.date,
                        location: _detail.location,
                      ),

                      const SizedBox(height: 16),

                      // Circle indicator
                      _CircleIndicator(memory: widget.memory),

                      const SizedBox(height: 20),

                      // Divider
                      Container(height: 0.5, color: AppTheme.outline),

                      const SizedBox(height: 20),

                      // Caption / story
                      _CaptionSection(caption: _detail.caption),

                      const SizedBox(height: 24),

                      // Tagged people
                      if (_detail.taggedPeople.isNotEmpty) ...[
                        _TaggedPeopleSection(people: _detail.taggedPeople),
                        const SizedBox(height: 24),
                      ],

                      // Divider
                      Container(height: 0.5, color: AppTheme.outline),

                      const SizedBox(height: 20),

                      // Reactions
                      _ReactionsRow(
                        reactions: _reactions,
                        commentCount: _comments.length,
                        onReactionTap: _onReactionTap,
                      ),

                      const SizedBox(height: 24),

                      // Divider
                      Container(height: 0.5, color: AppTheme.outline),

                      const SizedBox(height: 20),

                      // ── Comments Section ─────────────────────────────────
                      _CommentsSection(
                        comments: _comments,
                        isLoading: _isLoadingSocial,
                        onCommentPosted: _onCommentPosted,
                      ),

                      const SizedBox(height: 24),

                      // Divider
                      Container(height: 0.5, color: AppTheme.outline),

                      const SizedBox(height: 20),

                      // Add to Circle / Share action
                      _AddToCircleAction(
                        onTap: () => _showSnack('Add to Circle coming soon'),
                      ),

                      SizedBox(height: bottomPadding + 32),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Top bar overlay ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              title: widget.memory.title,
              topPadding: topPadding,
              onBack: () => Navigator.pop(context),
              onMenu: () => _showMenu(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  const _TopBar({
    required this.title,
    required this.topPadding,
    required this.onBack,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.backgroundDark.withAlpha(220), Colors.transparent],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // Back button
            _CircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),

            const SizedBox(width: 12),

            // Title (truncated)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Three-dot menu
            _CircleButton(icon: Icons.more_horiz_rounded, onTap: onMenu),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark.withAlpha(200),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.outline, width: 0.5),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textPrimary),
      ),
    );
  }
}

// ── Hero Media ────────────────────────────────────────────────────────────────

class _HeroMedia extends StatelessWidget {
  final MemoryItem memory;
  final bool isPlaying;
  final VoidCallback onPlayTap;
  final double topPadding;

  const _HeroMedia({
    required this.memory,
    required this.isPlaying,
    required this.onPlayTap,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final heroHeight = screenWidth * 1.1;

    return SizedBox(
      width: screenWidth,
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo / video thumbnail
          CachedNetworkImage(
            imageUrl: memory.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppTheme.surfaceVariantDark,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppTheme.surfaceVariantDark,
              child: const Icon(
                Icons.image_outlined,
                color: AppTheme.textDisabled,
                size: 48,
              ),
            ),
          ),

          // Bottom gradient for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppTheme.backgroundDark.withAlpha(180),
                    AppTheme.backgroundDark,
                  ],
                  stops: const [0.0, 0.55, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // Play button for video
          if (memory.type == MemoryType.video)
            Center(
              child: GestureDetector(
                onTap: onPlayTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? AppTheme.primaryGreen.withAlpha(220)
                        : Colors.black.withAlpha(160),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPlaying
                          ? AppTheme.primaryGreen
                          : Colors.white.withAlpha(120),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPlaying
                            ? AppTheme.primaryGreen.withAlpha(100)
                            : Colors.black.withAlpha(80),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 36,
                    color: isPlaying ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),

          // Video badge
          if (memory.type == MemoryType.video)
            Positioned(
              top: topPadding + 60,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withAlpha(80),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 12,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'VIDEO',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Meta Row (date + location) ────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final String date;
  final String location;

  const _MetaRow({required this.date, required this.location});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Date
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              date,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        // Dot separator — only when there's a location to separate from
        if (location.isNotEmpty) ...[
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: AppTheme.textDisabled,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
        ],

        // Location — only shown when we actually have one
        if (location.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppTheme.cyanAccent,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Circle Indicator ──────────────────────────────────────────────────────────

class _CircleIndicator extends StatelessWidget {
  final MemoryItem memory;

  const _CircleIndicator({required this.memory});

  @override
  Widget build(BuildContext context) {
    IconData privacyIcon;
    String privacyLabel;
    Color privacyColor;

    switch (memory.privacy) {
      case MemoryPrivacy.public:
        privacyIcon = Icons.public_rounded;
        privacyLabel = 'Public';
        privacyColor = AppTheme.cyanAccent;
        break;
      case MemoryPrivacy.circle:
        privacyIcon = Icons.group_rounded;
        privacyLabel = 'Circle';
        privacyColor = AppTheme.primaryGreen;
        break;
      case MemoryPrivacy.private:
        privacyIcon = Icons.lock_rounded;
        privacyLabel = 'Only me';
        privacyColor = AppTheme.textMuted;
        break;
    }

    return Row(
      children: [
        // Circle chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: memory.circleColor.withAlpha(22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: memory.circleColor.withAlpha(70),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: memory.circleColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: memory.circleColor.withAlpha(120),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                memory.circle,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: memory.circleColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Privacy pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: privacyColor.withAlpha(18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: privacyColor.withAlpha(55), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(privacyIcon, size: 12, color: privacyColor),
              const SizedBox(width: 5),
              Text(
                privacyLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: privacyColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Caption Section ───────────────────────────────────────────────────────────

class _CaptionSection extends StatefulWidget {
  final String caption;

  const _CaptionSection({required this.caption});

  @override
  State<_CaptionSection> createState() => _CaptionSectionState();
}

class _CaptionSectionState extends State<_CaptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.caption.length > 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'The Story',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.caption,
          maxLines: _expanded ? null : (isLong ? 3 : null),
          overflow: _expanded ? null : (isLong ? TextOverflow.ellipsis : null),
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            height: 1.65,
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Tagged People ─────────────────────────────────────────────────────────────

class _TaggedPeopleSection extends StatelessWidget {
  final List<_TaggedPerson> people;

  const _TaggedPeopleSection({required this.people});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'People in this memory',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: people.map((p) => _PersonChip(person: p)).toList(),
        ),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  final _TaggedPerson person;

  const _PersonChip({required this.person});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.memberProfileScreen,
          extra: {
            'memberName': person.name,
            'memberAvatarUrl': person.avatarUrl,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.outline, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: person.avatarUrl,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.surfaceElevatedDark,
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: AppTheme.textDisabled,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.surfaceElevatedDark,
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: AppTheme.textDisabled,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              person.name,
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

// ── Reactions Row ─────────────────────────────────────────────────────────

const _reactionPalette = ['❤️', '😂', '😮', '👏', '🔥'];

class _ReactionsRow extends StatelessWidget {
  final ReactionSummary reactions;
  final int commentCount;
  final void Function(String emoji) onReactionTap;

  const _ReactionsRow({
    required this.reactions,
    required this.commentCount,
    required this.onReactionTap,
  });

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.outline, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _reactionPalette.map((emoji) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onReactionTap(emoji);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = reactions.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...entries.map((entry) {
                final emoji = entry.key;
                final count = entry.value;
                final isMine = reactions.myEmoji == emoji;

                return GestureDetector(
                  onTap: () => onReactionTap(emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMine
                          ? AppTheme.primaryGreenGlow
                          : AppTheme.surfaceVariantDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isMine
                            ? AppTheme.primaryGreen.withAlpha(80)
                            : AppTheme.outline,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 5),
                        Text(
                          '$count',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isMine
                                ? AppTheme.primaryGreen
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Add-a-reaction button
              GestureDetector(
                onTap: () => _openPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outline, width: 0.8),
                  ),
                  child: const Icon(
                    Icons.add_reaction_outlined,
                    size: 17,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Comment count
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 15,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              '$commentCount',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Comments Section ──────────────────────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  final List<MemoryComment> comments;
  final bool isLoading;
  final void Function(String text) onCommentPosted;

  const _CommentsSection({
    required this.comments,
    required this.isLoading,
    required this.onCommentPosted,
  });

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading row
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Comments',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenGlow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGreen.withAlpha(60),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${comments.length}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryGreen,
              ),
            ),
          )
        else if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No comments yet — be the first.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          )
        else
          ...comments.map(
            (c) => _CommentCard(comment: c, timeAgo: _timeAgo(c.createdAt)),
          ),

        const SizedBox(height: 16),

        // Add a comment input
        _CommentInputField(onSubmit: onCommentPosted),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final MemoryComment comment;
  final String timeAgo;

  const _CommentCard({required this.comment, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.author?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ClipOval(
            child: avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppTheme.surfaceElevatedDark,
                      child: const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: AppTheme.textDisabled,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surfaceElevatedDark,
                      child: const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: AppTheme.textDisabled,
                      ),
                    ),
                  )
                : Container(
                    width: 36,
                    height: 36,
                    color: AppTheme.surfaceElevatedDark,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: AppTheme.textDisabled,
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          // Comment bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppTheme.outline, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + timestamp
                  Row(
                    children: [
                      Text(
                        comment.author?.displayName ?? 'Member',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textDisabled,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Comment text
                  Text(
                    comment.body,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInputField extends StatefulWidget {
  final void Function(String text) onSubmit;

  const _CommentInputField({required this.onSubmit});

  @override
  State<_CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<_CommentInputField> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _hasText
              ? AppTheme.primaryGreen.withAlpha(100)
              : AppTheme.outline,
          width: _hasText ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          // My avatar placeholder
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 16,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.textDisabled,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
            ),
          ),
          // Send button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: _hasText ? AppTheme.primaryGradient : null,
                color: _hasText ? null : AppTheme.surfaceElevatedDark,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _hasText ? _submit : null,
                icon: Icon(
                  Icons.send_rounded,
                  size: 16,
                  color: _hasText ? Colors.black : AppTheme.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add to Circle Action ──────────────────────────────────────────────────────

class _AddToCircleAction extends StatelessWidget {
  final VoidCallback onTap;

  const _AddToCircleAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGreen.withAlpha(18),
              AppTheme.cyanAccent.withAlpha(12),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryGreen.withAlpha(55),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add_rounded,
                size: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Add to Circle',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu Bottom Sheet ─────────────────────────────────────────────────────────

class _MemoryMenuSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _MemoryMenuSheet({
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          _MenuTile(
            icon: Icons.edit_rounded,
            label: 'Edit Memory',
            color: AppTheme.textPrimary,
            onTap: onEdit,
          ),
          _MenuTile(
            icon: Icons.share_rounded,
            label: 'Share Memory',
            color: AppTheme.cyanAccent,
            onTap: onShare,
          ),
          Container(
            height: 0.5,
            color: AppTheme.outline,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _MenuTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Memory',
            color: AppTheme.error,
            onTap: onDelete,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete Confirm Dialog ─────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _DeleteConfirmDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 28,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Memory?',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This memory will be permanently removed from your collection and all Circles.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}