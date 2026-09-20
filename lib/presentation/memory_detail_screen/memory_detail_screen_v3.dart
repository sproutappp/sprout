import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase/supabase_service.dart';
import '../../models/comment.dart';
import '../../models/memory.dart';
import '../../models/profile.dart';
import '../../presentation/memories_screen/widgets/memories_grid_widget.dart';
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
      final reactions = await ReactionsRepository.fetchSummary(_id);
      final comments = await CommentsRepository.fetchForMemory(_id);
      if (!mounted) return;
      setState(() {
        _reactions = reactions;
        _comments = comments;
        _loadingSocial = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSocial = false);
    }
  }

  Future<void> _loadPeople() async {
    try {
      final people = await MemoryPeopleRepository.fetchForMemory(_id);
      if (!mounted) return;
      setState(() => _taggedPeople = people);
    } catch (_) {
      if (mounted) setState(() => _taggedPeople = []);
    }
  }

  Future<void> _share() async {
    final memory = _memory;
    if (memory == null) return;
    final title = (memory.caption ?? '').split(' — ').first.trim();
    try {
      await SharePlus.instance.share(ShareParams(
        uri: Uri.parse('https://sproutapp.in/memory/${memory.id}'),
        title: title.isEmpty ? 'A memory on Sprout' : title,
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
        title: const Text('Delete memory?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This memory and its circle shares will be removed.', style: TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MemoriesRepository.deleteMemory(_id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
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
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add to Circle', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Choose one or more circles you follow.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 12),
                  if (circles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text("You don't follow any circles yet.", style: TextStyle(color: AppTheme.textMuted)),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: circles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final circle = circles[index];
                          final isSelected = selected.contains(circle.id);
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setSheetState(() {
                              if (isSelected) selected.remove(circle.id); else selected.add(circle.id);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryGreen.withAlpha(28) : AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isSelected ? AppTheme.primaryGreen.withAlpha(150) : AppTheme.outline),
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
                                          ? DecorationImage(image: NetworkImage(circle.coverImageUrl!), fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: circle.coverImageUrl?.isNotEmpty == true
                                        ? null
                                        : const Icon(Icons.groups_rounded, color: AppTheme.textMuted, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(circle.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700))),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppTheme.primaryGreen,
                                    onChanged: (value) => setSheetState(() {
                                      if (value == true) selected.add(circle.id); else selected.remove(circle.id);
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
                      onPressed: selected.isEmpty ? null : () => Navigator.pop(sheetContext, selected.toList()),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.black),
                      child: const Text('Add to selected circles', style: TextStyle(fontWeight: FontWeight.w800)),
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
        await MemoryEditRepository.addToCircle(memoryId: _id, circleId: circleId);
      }
      if (mounted) _snack(result.length == 1 ? 'Memory added to the circle.' : 'Memory added to ${result.length} circles.');
    } catch (e) {
      debugPrint('MemoryDetailScreenV3: add to circle failed: $e');
      if (mounted) _snack("Couldn't add this memory to the circle.");
    } finally {
      if (mounted) setState(() => _addingToCircle = false);
    }
  }

  Future<void> _toggleReaction() async {
    try {
      if (_reactions.myEmoji == '❤️') {
        await ReactionsRepository.removeReaction(_id);
      } else {
        await ReactionsRepository.setReaction(_id, '❤️');
      }
      await _loadSocial();
    } catch (_) {
      if (mounted) _snack('Reactions are unavailable for this memory right now.');
    }
  }

  Future<void> _showComments() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comments', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              if (_comments.isEmpty)
                const Text('Be the first to comment.', style: TextStyle(color: AppTheme.textMuted))
              else
                ..._comments.map((comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(comment.body, style: const TextStyle(color: AppTheme.textPrimary)),
                )),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: controller, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(hintText: 'Write a comment...'))),
                  IconButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      try {
                        final comment = await CommentsRepository.addComment(memoryId: _id, body: text);
                        if (!mounted) return;
                        setState(() => _comments = [..._comments, comment]);
                        controller.clear();
                      } catch (_) {
                        if (mounted) _snack("Couldn't post comment.");
                      }
                    },
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primaryGreen),
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

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

  String _title(Memory memory) {
    final value = (memory.caption ?? '').split(' — ').first.trim();
    return value.isEmpty ? 'A shared memory' : value;
  }

  String _story(Memory memory) {
    final parts = (memory.caption ?? '').split(' — ');
    return parts.length > 1 ? parts.sublist(1).join(' — ').trim() : '';
  }

  void _openPhotoViewer(int index) {
    final urls = _memory?.mediaUrls ?? const <String>[];
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MemoryPhotoViewerScreen(imageUrls: urls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppTheme.backgroundDark, body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
    }
    final memory = _memory;
    if (memory == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(backgroundColor: AppTheme.backgroundDark, foregroundColor: AppTheme.textPrimary),
        body: const Center(child: Text('This memory is no longer available.', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    final title = _title(memory);
    final story = _story(memory);
    final publicMemory = memory.isPublic;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: AppTheme.textPrimary,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _share, icon: const Icon(Icons.share_rounded)),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _edit();
                if (value == 'delete') _delete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit Memory')),
                PopupMenuItem(value: 'delete', child: Text('Delete Memory')),
              ],
            ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GestureDetector(
            onTap: () => _openPhotoViewer(0),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: memory.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceVariantDark, child: const Icon(Icons.image_outlined, color: AppTheme.textDisabled, size: 48)),
                  ),
                  if (memory.mediaUrls.length > 1)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withAlpha(170), borderRadius: BorderRadius.circular(16)),
                        child: Text('${memory.mediaUrls.length} photos', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text('${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}', style: const TextStyle(color: AppTheme.textMuted)),
                  const SizedBox(width: 16),
                  Icon(publicMemory ? Icons.public_rounded : Icons.group_rounded, size: 14, color: publicMemory ? AppTheme.cyanAccent : AppTheme.primaryGreen),
                  const SizedBox(width: 5),
                  Text(publicMemory ? 'Public' : (memory.circleName ?? 'Circle'), style: TextStyle(color: publicMemory ? AppTheme.cyanAccent : AppTheme.primaryGreen, fontWeight: FontWeight.w700)),
                ]),
                if ((memory.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted), const SizedBox(width: 5), Expanded(child: Text(memory.location!, style: const TextStyle(color: AppTheme.textMuted)))]),
                ],
                if (story.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(story, style: GoogleFonts.manrope(fontSize: 15, height: 1.5, color: AppTheme.textPrimary)),
                ],
                if (_taggedPeople.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('People in this memory', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _taggedPeople.map((person) => Chip(
                      avatar: person.avatarUrl == null ? null : CircleAvatar(backgroundImage: NetworkImage(person.avatarUrl!)),
                      label: Text(person.displayName),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 22),
                Row(children: [
                  OutlinedButton.icon(onPressed: _toggleReaction, icon: const Icon(Icons.favorite_border_rounded, size: 17), label: Text('${_reactions.totalCount}')),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(onPressed: _showComments, icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17), label: Text('${_comments.length}')),
                  const Spacer(),
                  OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share_rounded, size: 17), label: const Text('Share')),
                ]),
                const SizedBox(height: 24),
                if (!_loadingSocial && _comments.isNotEmpty) ...[
                  Text('Comments', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  ..._comments.take(3).map((comment) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(comment.body, style: const TextStyle(color: AppTheme.textMuted)))),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _addingToCircle ? null : _addToCircle,
                    icon: _addingToCircle
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                        : const Icon(Icons.group_add_rounded, color: AppTheme.primaryGreen),
                    label: Text('Add to Circle', style: GoogleFonts.manrope(color: AppTheme.primaryGreen, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
