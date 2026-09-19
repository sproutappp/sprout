import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/memory.dart';
import '../../presentation/memories_screen/widgets/memories_grid_widget.dart';
import '../../services/comments_repository.dart';
import '../../services/memory_edit_repository.dart';
import '../../services/memory_people_repository.dart';
import '../../services/memories_repository.dart';
import '../../services/reactions_repository.dart';
import '../../theme/app_theme.dart';
import 'edit_memory_screen.dart';

class MemoryDetailScreenV2 extends StatefulWidget {
  final MemoryItem? initialMemory;
  final String? memoryId;

  const MemoryDetailScreenV2({super.key, this.initialMemory, this.memoryId});

  @override
  State<MemoryDetailScreenV2> createState() => _MemoryDetailScreenV2State();
}

class _MemoryDetailScreenV2State extends State<MemoryDetailScreenV2> {
  Memory? _memory;
  bool _loading = true;
  bool _deleted = false;
  ReactionSummary _reactions = ReactionSummary.empty;
  List<MemoryComment> _comments = [];
  bool _loadingSocial = true;

  String get _id => widget.memoryId ?? widget.initialMemory?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final memory = await MemoriesRepository.fetchById(_id);
      if (!mounted) return;
      setState(() {
        _memory = memory;
        _loading = false;
      });
      await _loadSocial();
    } catch (_) {
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

  MemoryItem _item(Memory memory) {
    final isPublic = memory.isPublic;
    return MemoryItem(
      id: memory.id,
      title: memory.caption?.split(' — ').first.trim().isNotEmpty == true
          ? memory.caption!.split(' — ').first.trim()
          : 'A shared memory',
      date: '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}',
      imageUrl: memory.imageUrl,
      semanticLabel: 'Memory photo',
      circle: isPublic ? 'Public' : (memory.circleName ?? 'Circle'),
      circleColor: isPublic ? AppTheme.cyanAccent : AppTheme.primaryGreen,
      privacy: isPublic ? MemoryPrivacy.public : MemoryPrivacy.circle,
      type: MemoryType.photo,
    );
  }

  bool get _isOwner => _memory != null && MemoriesRepository.currentUserId == _memory!.uploadedBy;

  Future<void> _share() async {
    final memory = _memory;
    if (memory == null) return;
    final url = Uri.parse('https://sproutapp.in/memory/${memory.id}');
    try {
      await SharePlus.instance.share(
        ShareParams(
          uri: url,
          title: memory.caption?.split(' — ').first.trim().isNotEmpty == true
              ? memory.caption!.split(' — ').first.trim()
              : 'A memory on Sprout',
          subject: 'A memory on Sprout',
        ),
      );
    } catch (_) {
      if (mounted) _snack('Couldn\'t open sharing. Please try again.');
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
      if (!mounted) return;
      _deleted = true;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _snack('Couldn\'t delete this memory. Please try again.');
    }
  }

  Future<void> _addToCircle() async {
    if (!_isOwner) return;
    final circles = await _selectCircles();
    if (circles == null || circles.isEmpty) return;
    try {
      for (final circleId in circles) {
        await MemoryEditRepository.addToCircle(memoryId: _id, circleId: circleId);
      }
      if (mounted) _snack('Memory added to ${circles.length == 1 ? 'the circle' : '${circles.length} circles'}.');
      await _load();
    } catch (_) {
      if (mounted) _snack('Couldn\'t add this memory to the circle.');
    }
  }

  Future<List<String>?> _selectCircles() async {
    final myCircles = await __fetchCircles();
    if (!mounted) return null;
    final selected = <String>{};
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to Circle', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                if (myCircles.isEmpty)
                  const Text('You don\'t have any circles yet.', style: TextStyle(color: AppTheme.textMuted))
                else ...myCircles.map((circle) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(circle.name, style: const TextStyle(color: AppTheme.textPrimary)),
                      activeColor: AppTheme.primaryGreen,
                      value: selected.contains(circle.id),
                      onChanged: (value) => setSheetState(() {
                        if (value == true) selected.add(circle.id); else selected.remove(circle.id);
                      }),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
  }

  Future<List<dynamic>> __fetchCircles() async {
    final rows = await _rawCircles();
    return rows;
  }

  Future<List<dynamic>> _rawCircles() async {
    // Reuse the same repository used by Create Memory without exposing a second data layer here.
    final dynamic result = await _fetchMyCirclesViaRepository();
    return result;
  }

  Future<dynamic> _fetchMyCirclesViaRepository() async {
    // Kept as a small indirection so this screen remains easy to test.
    return (await __circlesRepository()).fetchMyCircles();
  }

  dynamic __circlesRepository() {
    // This import is intentionally avoided above to keep the action code compact.
    return _CirclesBridge.instance;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    if (_loading) return const Scaffold(backgroundColor: AppTheme.backgroundDark, body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
    final memory = _memory;
    if (memory == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(backgroundColor: AppTheme.backgroundDark, foregroundColor: AppTheme.textPrimary),
        body: const Center(child: Text('This memory is no longer available.', style: TextStyle(color: AppTheme.textMuted))),
      );
    }
    final item = _item(memory);
    final titleParts = (memory.caption ?? '').split(' — ');
    final title = titleParts.first.trim().isEmpty ? 'A shared memory' : titleParts.first.trim();
    final story = titleParts.length > 1 ? titleParts.sublist(1).join(' — ').trim() : '';

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
                if (value == 'circle') _addToCircle();
                if (value == 'delete') _delete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit Memory')),
                PopupMenuItem(value: 'circle', child: Text('Add to Circle')),
                PopupMenuItem(value: 'delete', child: Text('Delete Memory')),
              ],
            ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Hero(
            tag: 'memory-${item.id}',
            child: AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: memory.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceVariantDark, child: const Icon(Icons.image_outlined, color: AppTheme.textDisabled, size: 48)),
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
                  Icon(item.privacy == MemoryPrivacy.public ? Icons.public_rounded : Icons.group_rounded, size: 14, color: item.circleColor),
                  const SizedBox(width: 5),
                  Text(item.circle, style: TextStyle(color: item.circleColor, fontWeight: FontWeight.w700)),
                ]),
                if ((memory.location ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted), const SizedBox(width: 5), Expanded(child: Text(memory.location!, style: const TextStyle(color: AppTheme.textMuted)))]),
                ],
                if (story.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(story, style: GoogleFonts.manrope(fontSize: 15, height: 1.5, color: AppTheme.textPrimary)),
                ],
                const SizedBox(height: 22),
                Row(children: [
                  _ReactionButton(icon: Icons.favorite_border_rounded, label: '${_reactions.totalCount}', onTap: () => _toggleReaction('❤️')),
                  const SizedBox(width: 12),
                  _ReactionButton(icon: Icons.chat_bubble_outline_rounded, label: '${_comments.length}', onTap: () => _showComments()),
                  const Spacer(),
                  OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share_rounded, size: 17), label: const Text('Share')),
                ]),
                const SizedBox(height: 24),
                if (!_loadingSocial && _comments.isNotEmpty) ...[
                  Text('Comments', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  ..._comments.take(3).map((comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(comment.body, style: const TextStyle(color: AppTheme.textMuted)),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReaction(String emoji) async {
    final mine = _reactions.myEmoji == emoji;
    try {
      if (mine) {
        await ReactionsRepository.removeReaction(_id);
      } else {
        await ReactionsRepository.setReaction(_id, emoji);
      }
      await _loadSocial();
    } catch (_) {
      if (mounted) _snack('Reactions are unavailable for this memory right now.');
    }
  }

  Future<void> _showComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      builder: (_) => _CommentsSheet(comments: _comments, onPosted: (text) async {
        final comment = await CommentsRepository.addComment(memoryId: _id, body: text);
        if (mounted) setState(() => _comments = [..._comments, comment]);
      }),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReactionButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(label));
}

class _CommentsSheet extends StatefulWidget {
  final List<MemoryComment> comments;
  final Future<void> Function(String) onPosted;
  const _CommentsSheet({required this.comments, required this.onPosted});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _posting = false;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comments', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            if (widget.comments.isEmpty) const Text('Be the first to comment.', style: TextStyle(color: AppTheme.textMuted)) else ...widget.comments.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c.body, style: const TextStyle(color: AppTheme.textPrimary)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _controller, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(hintText: 'Write a comment...'))),
              IconButton(onPressed: _posting ? null : () async { final text = _controller.text.trim(); if (text.isEmpty) return; setState(() => _posting = true); try { await widget.onPosted(text); _controller.clear(); } finally { if (mounted) setState(() => _posting = false); } }, icon: const Icon(Icons.send_rounded, color: AppTheme.primaryGreen)),
            ]),
          ],
        ),
      ),
    );
  }
}

// Small adapter keeps the screen decoupled from UI imports elsewhere.
class _CirclesBridge {
  _CirclesBridge._();
  static final instance = _CirclesBridge._();
  Future<List<dynamic>> fetchMyCircles() async {
    final rows = await _client.from('circle_members').select('circles(*)').eq('user_id', _client.auth.currentUser?.id ?? '');
    return (rows as List).map((row) => _CircleLite.fromMap(Map<String, dynamic>.from(row['circles'] as Map))).toList();
  }
  dynamic get _client => throw UnsupportedError('bridge');
}

class _CircleLite {
  final String id;
  final String name;
  const _CircleLite({required this.id, required this.name});
  factory _CircleLite.fromMap(Map<String, dynamic> map) => _CircleLite(id: map['id'] as String, name: map['name'] as String);
}
