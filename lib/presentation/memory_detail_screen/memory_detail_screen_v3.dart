import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase/supabase_service.dart';
import '../../models/comment.dart';
import '../../models/memory.dart';
import '../../models/profile.dart';
import '../../services/circles_repository.dart';
import '../../services/comments_repository.dart';
import '../../services/memory_edit_repository.dart';
import '../../services/memory_people_repository.dart';
import '../../services/memories_repository.dart';
import '../../services/reactions_repository.dart';
import '../../theme/app_theme.dart';
import '../edit_memory_screen/edit_memory_screen.dart';
import 'memory_photo_viewer_screen.dart';

class MemoryDetailScreenV3 extends StatefulWidget {
  final MemoryItem? initialMemory;
  final String? memoryId;

  const MemoryDetailScreenV3({super.key, this.initialMemory, this.memoryId});

  @override
  State<MemoryDetailScreenV3> createState() => _MemoryDetailScreenV3State();
}

class _MemoryDetailScreenV3State extends State<MemoryDetailScreenV3> {
  Memory? _memory;
  List<MemoryComment> _comments = [];
  List<Profile> _taggedPeople = [];
  ReactionSummary _reactions = ReactionSummary.empty;
  bool _loading = true;
  bool _loadingSocial = true;
  bool _addingToCircle = false;

  String get _id => widget.memoryId ?? widget.initialMemory?.id ?? '';

  bool get _isOwner => _memory != null &&
      SupabaseService.client.auth.currentUser?.id == _memory!.uploadedBy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_id.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final memory = await MemoriesRepository.fetchById(_id);
      if (!mounted) return;
      setState(() {
        _memory = memory;
        _loading = false;
      });

      if (memory == null) return;
      await Future.wait([_loadSocial(), _loadPeople()]);
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSocial() async {
    try {
      final results = await Future.wait([
        ReactionsRepository.fetchSummary(_id),
        CommentsRepository.fetchForMemory(_id),
      ]);
      if (!mounted) return;
      setState(() {
        _reactions = results[0] as ReactionSummary;
        _comments = results[1] as List<MemoryComment>;
        _loadingSocial = false;
      });
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: social load failed: $e');
      if (mounted) setState(() => _loadingSocial = false);
    }
  }

  Future<void> _loadPeople() async {
    try {
      final people = await MemoryPeopleRepository.fetchForMemory(_id);
      if (!mounted) return;
      setState(() => _taggedPeople = people);
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: people load failed: $e');
      if (mounted) setState(() => _taggedPeople = []);
    }
  }

  Future<void> _share() async {
    final memory = _memory;
    if (memory == null) return;
    final title = _title(memory);
    try {
      await SharePlus.instance.share(ShareParams(
        uri: Uri.parse('https://sproutapp.in/memory/${memory.id}'),
        title: title,
        subject: 'A memory on Sprout',
      ));
    } catch (_) {
      if (mounted) _snack("Couldn't open sharing. Please try again.");
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditMemoryScreen(memoryId: _id)),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Delete memory?',
          style: GoogleFonts.manrope(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This memory and its circle shares will be removed.',
          style: GoogleFonts.manrope(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await MemoriesRepository.deleteMemory(_id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: delete failed: $e');
      if (mounted) _snack("Couldn't delete this memory. Please try again.");
    }
  }

  Future<void> _addToCircle() async {
    if (_addingToCircle) return;
    setState(() => _addingToCircle = true);

    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() => _addingToCircle = false);

      final selected = <String>{};
      final result = await showModalBottomSheet<List<String>>(
        context: context,
        backgroundColor: AppTheme.surfaceDark,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(sheetContext).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.outline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Add to Circle',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose one or more circles you follow.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (circles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "You don't follow any circles yet.",
                        style: GoogleFonts.manrope(color: AppTheme.textMuted),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: circles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, index) {
                          final circle = circles[index];
                          final isSelected = selected.contains(circle.id);
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setSheetState(() {
                              if (isSelected) {
                                selected.remove(circle.id);
                              } else {
                                selected.add(circle.id);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryGreen.withAlpha(28)
                                    : AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryGreen.withAlpha(150)
                                      : AppTheme.outline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.surfaceVariantDark,
                                      image: circle.coverImageUrl?.isNotEmpty == true
                                          ? DecorationImage(
                                              image: NetworkImage(circle.coverImageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: circle.coverImageUrl?.isNotEmpty == true
                                        ? null
                                        : const Icon(
                                            Icons.groups_rounded,
                                            color: AppTheme.textMuted,
                                            size: 20,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      circle.name,
                                      style: GoogleFonts.manrope(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppTheme.primaryGreen,
                                    onChanged: (value) => setSheetState(() {
                                      if (value == true) {
                                        selected.add(circle.id);
                                      } else {
                                        selected.remove(circle.id);
                                      }
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                                sheetContext,
                                selected.toList(),
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Add to selected circles',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (result == null || result.isEmpty) return;
      for (final circleId in result) {
        await MemoryEditRepository.addToCircle(
          memoryId: _id,
          circleId: circleId,
        );
      }
      if (mounted) {
        _snack(
          result.length == 1
              ? 'Memory added to the circle.'
              : 'Memory added to ${result.length} circles.',
        );
      }
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: add to circle failed: $e');
      if (mounted) _snack("Couldn't add this memory to the circle.");
    } finally {
      if (mounted) setState(() => _addingToCircle = false);
    }
  }

  Future<void> _toggleReaction(String emoji) async {
    final previous = _reactions;
    final mine = _reactions.myEmoji == emoji;
    final counts = Map<String, int>.from(_reactions.counts);

    if (_reactions.myEmoji != null) {
      final old = _reactions.myEmoji!;
      counts[old] = (counts[old] ?? 1) - 1;
      if (counts[old]! <= 0) counts.remove(old);
    }
    if (!mine) counts[emoji] = (counts[emoji] ?? 0) + 1;

    setState(() {
      _reactions = ReactionSummary(
        counts: counts,
        myEmoji: mine ? null : emoji,
      );
    });

    try {
      if (mine) {
        await ReactionsRepository.removeReaction(_id);
      } else {
        await ReactionsRepository.setReaction(_id, emoji);
      }
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: reaction failed: $e');
      if (mounted) setState(() => _reactions = previous);
    }
  }

  Future<void> _showComments() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_comments.isEmpty)
                const Text(
                  'Be the first to comment.',
                  style: TextStyle(color: AppTheme.textMuted),
                )
              else
                ..._comments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      comment.body,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      try {
                        final comment = await CommentsRepository.addComment(
                          memoryId: _id,
                          body: text,
                        );
                        if (!mounted) return;
                        setState(() => _comments = [..._comments, comment]);
                        controller.clear();
                      } catch (e) {
                        debugPrint('MemoryDetailScreenV3: comment failed: $e');
                        if (mounted) _snack("Couldn't post comment.");
                      }
                    },
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfaceElevatedDark,
      ),
    );
  }

  String _title(Memory memory) {
    final value = (memory.caption ?? '').split(' — ').first.trim();
    return value.isEmpty ? 'A shared memory' : value;
  }

  String _story(Memory memory) {
    final parts = (memory.caption ?? '').split(' — ');
    return parts.length > 1 ? parts.sublist(1).join(' — ').trim() : '';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openPhotoViewer(int index) {
    final urls = _memory?.mediaUrls ?? const <String>[];
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MemoryPhotoViewerScreen(
          imageUrls: urls,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    final memory = _memory;
    if (memory == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundDark,
          foregroundColor: AppTheme.textPrimary,
        ),
        body: const Center(
          child: Text(
            'This memory is no longer available.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final title = _title(memory);
    final story = _story(memory);
    final isPublic = memory.isPublic;
    final circleName = memory.circleName?.trim() ?? '';
    final hasLocation = (memory.location ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _MemoryHero(
                memory: memory,
                title: title,
                onBack: () => Navigator.pop(context),
                onShare: _share,
                onMenu: _isOwner ? _showOwnerMenu : null,
                onPhotoTap: (index) => _openPhotoViewer(index),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(memory.createdAt),
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        if (hasLocation) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppTheme.cyanAccent,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              memory.location!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        if (!isPublic && circleName.isNotEmpty)
                          _Pill(
                            icon: Icons.circle,
                            label: circleName,
                            color: AppTheme.primaryGreen,
                          )
                        else
                          _Pill(
                            icon: Icons.public_rounded,
                            label: 'Public',
                            color: AppTheme.cyanAccent,
                          ),
                        if (!isPublic && circleName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Pill(
                            icon: Icons.group_rounded,
                            label: 'Circle',
                            color: AppTheme.primaryGreen,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionDivider(),
                    const SizedBox(height: 14),
                    if (story.isNotEmpty) ...[
                      _SectionTitle(title: 'The Story'),
                      const SizedBox(height: 9),
                      _StoryText(text: story),
                      const SizedBox(height: 15),
                    ],
                    if (_taggedPeople.isNotEmpty) ...[
                      _SectionTitle(title: 'People in this memory'),
                      const SizedBox(height: 9),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _taggedPeople.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 7),
                          itemBuilder: (_, index) => _PersonChip(
                            person: _taggedPeople[index],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                    _SectionDivider(),
                    const SizedBox(height: 13),
                    _ReactionBar(
                      reactions: _reactions,
                      commentCount: _comments.length,
                      onReaction: _toggleReaction,
                      onComments: _showComments,
                    ),
                    const SizedBox(height: 15),
                    _SectionDivider(),
                    const SizedBox(height: 14),
                    _CommentsBlock(
                      comments: _comments,
                      loading: _loadingSocial,
                      timeAgo: _timeAgo,
                    ),
                    const SizedBox(height: 14),
                    _CommentInput(onSubmit: (text) async {
                      try {
                        final comment = await CommentsRepository.addComment(
                          memoryId: _id,
                          body: text,
                        );
                        if (!mounted) return;
                        setState(() => _comments = [..._comments, comment]);
                      } catch (e) {
                        debugPrint('MemoryDetailScreenV3: comment failed: $e');
                        if (mounted) _snack("Couldn't post comment.");
                      }
                    }),
                    const SizedBox(height: 15),
                    _SectionDivider(),
                    const SizedBox(height: 14),
                    _AddToCircleButton(
                      loading: _addingToCircle,
                      onTap: _addToCircle,
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 24,
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

  void _showOwnerMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.outline),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.edit_rounded,
                label: 'Edit Memory',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _edit();
                },
              ),
              _MenuItem(
                icon: Icons.share_rounded,
                label: 'Share Memory',
                color: AppTheme.cyanAccent,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _share();
                },
              ),
              Container(height: 0.5, color: AppTheme.outline),
              _MenuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Memory',
                color: AppTheme.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _delete();
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryHero extends StatefulWidget {
  final Memory memory;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback? onMenu;
  final ValueChanged<int> onPhotoTap;

  const _MemoryHero({
    required this.memory,
    required this.title,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
    required this.onPhotoTap,
  });

  @override
  State<_MemoryHero> createState() => _MemoryHeroState();
}

class _MemoryHeroState extends State<_MemoryHero> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPhoto() {
    final total = widget.memory.mediaUrls.length;
    if (total < 2 || _currentIndex >= total - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = (width * 0.98).clamp(230.0, 390.0).toDouble();
    final urls = widget.memory.mediaUrls;
    final total = urls.length;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: total > 0 ? total : 1,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, index) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onPhotoTap(index),
              child: total > 0
                  ? CachedNetworkImage(
                      imageUrl: urls[index],
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceVariantDark,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.textDisabled,
                          size: 42,
                        ),
                      ),
                    )
                  : Container(
                      color: AppTheme.surfaceVariantDark,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppTheme.textDisabled,
                        size: 42,
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.16, 0.78, 1.0],
                    colors: [
                      Colors.black.withAlpha(95),
                      Colors.transparent,
                      Colors.transparent,
                      AppTheme.backgroundDark.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                _HeroButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: widget.onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HeroButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: widget.onMenu ?? widget.onShare,
                ),
              ],
            ),
          ),
          if (total > 1 && _currentIndex < total - 1)
            Positioned(
              right: 12,
              top: height / 2 - 19,
              child: GestureDetector(
                onTap: _goToNextPhoto,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(145),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(70)),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 25,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (index) {
                  final active = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: active ? 8 : 6,
                    height: active ? 8 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withAlpha(125),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(105),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(45)),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withAlpha(80), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 0.6, color: AppTheme.outline);
  }
}

class _StoryText extends StatefulWidget {
  final String text;

  const _StoryText({required this.text});

  @override
  State<_StoryText> createState() => _StoryTextState();
}

class _StoryTextState extends State<_StoryText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 170;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: long && !_expanded ? 4 : null,
          overflow: long && !_expanded ? TextOverflow.ellipsis : null,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            height: 1.65,
            color: AppTheme.textSecondary,
          ),
        ),
        if (long) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  final Profile person;

  const _PersonChip({required this.person});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppTheme.surfaceElevatedDark,
            backgroundImage: person.avatarUrl?.isNotEmpty == true
                ? NetworkImage(person.avatarUrl!)
                : null,
            child: person.avatarUrl?.isNotEmpty == true
                ? null
                : const Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: AppTheme.textDisabled,
                  ),
          ),
          const SizedBox(width: 5),
          Text(
            person.displayName,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  final ReactionSummary reactions;
  final int commentCount;
  final Future<void> Function(String emoji) onReaction;
  final VoidCallback onComments;

  const _ReactionBar({
    required this.reactions,
    required this.commentCount,
    required this.onReaction,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reactions.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () => onReaction(entry.key),
                      child: _ReactionPill(
                        emoji: entry.key,
                        count: entry.value,
                        selected: reactions.myEmoji == entry.key,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantDark,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.outline, width: 0.6),
                    ),
                    child: const Icon(
                      Icons.add_reaction_outlined,
                      size: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onComments,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 13,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '$commentCount',
                style: GoogleFonts.manrope(
                  fontSize: 9.5,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openPicker(BuildContext context) {
    const palette = ['❤️', '😂', '😮', '👏', '🔥'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: palette
                .map(
                  (emoji) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReaction(emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  final String emoji;
  final int count;
  final bool selected;

  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primaryGreen.withAlpha(30)
            : AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected
              ? AppTheme.primaryGreen.withAlpha(100)
              : AppTheme.outline,
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsBlock extends StatelessWidget {
  final List<MemoryComment> comments;
  final bool loading;
  final String Function(DateTime) timeAgo;

  const _CommentsBlock({
    required this.comments,
    required this.loading,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionTitle(title: 'Comments'),
            const Spacer(),
            if (comments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${comments.length}',
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (loading)
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryGreen,
            ),
          )
        else if (comments.isEmpty)
          Text(
            'No comments yet — be the first.',
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          )
        else
          ...comments.map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _CommentCard(
                comment: comment,
                timeAgo: timeAgo(comment.createdAt),
              ),
            ),
          ),
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
    final avatar = comment.author?.avatarUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppTheme.surfaceElevatedDark,
          backgroundImage: avatar?.isNotEmpty == true
              ? NetworkImage(avatar!)
              : null,
          child: avatar?.isNotEmpty == true
              ? null
              : const Icon(
                  Icons.person_rounded,
                  size: 13,
                  color: AppTheme.textDisabled,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(11),
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author?.displayName ?? 'Member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeAgo,
                      style: GoogleFonts.manrope(
                        fontSize: 7.5,
                        color: AppTheme.textDisabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: GoogleFonts.manrope(
                    fontSize: 9.5,
                    height: 1.45,
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

class _CommentInput extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;

  const _CommentInput({required this.onSubmit});

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    await widget.onSubmit(text);
    if (!mounted) return;
    controller.clear();
    setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline, width: 0.6),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 9.5,
                  color: AppTheme.textDisabled,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
            ),
          ),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 25,
              height: 25,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevatedDark,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      size: 12,
                      color: AppTheme.textDisabled,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddToCircleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _AddToCircleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGreen.withAlpha(65),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(
                      Icons.group_add_rounded,
                      size: 13,
                      color: Colors.black,
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              'Add to Circle',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
