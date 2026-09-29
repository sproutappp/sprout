import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/memory.dart';
import '../../routes/app_routes.dart';
import '../../services/comments_repository.dart';
import '../../services/discover_refresh_bus.dart';
import '../../services/memories_repository.dart';
import '../../services/reactions_repository.dart';
import '../../theme/app_theme.dart';
import '../memories_screen/widgets/memories_grid_widget.dart'
    show MemoryItem, MemoryPrivacy, MemoryType;

enum _DiscoverMode { forYou, nearby }

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  bool _loadFailed = false;
  _DiscoverMode _mode = _DiscoverMode.forYou;
  List<Memory> _memories = [];
  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  Timer? _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    DiscoverRefreshBus.signal.addListener(_onRefreshRequested);
    _relativeTimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _memories.isNotEmpty) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    DiscoverRefreshBus.signal.removeListener(_onRefreshRequested);
    _relativeTimeTimer?.cancel();
    super.dispose();
  }

  void _onRefreshRequested() {
    if (mounted) _load();
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location to see nearby memories.')),
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is needed for Nearby.')),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _selectMode(_DiscoverMode mode) async {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      _isLoading = true;
      _loadFailed = false;
    });

    await _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }

    try {
      List<Memory> memories;

      if (_mode == _DiscoverMode.forYou) {
        memories = await MemoriesRepository.fetchPublicMemories();
      } else {
        final allowed = await _ensureLocationPermission();
        if (!allowed) {
          if (!mounted) return;
          setState(() {
            _memories = [];
            _likeCounts = {};
            _commentCounts = {};
            _isLoading = false;
          });
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );

        memories = await MemoriesRepository.fetchNearbyPublicMemories(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }

      if (!mounted) return;

      final memoryIds = memories.map((memory) => memory.id).toList();
      final likeCountsFuture = ReactionsRepository.fetchLikeCounts(memoryIds);
      final commentResultsFuture = Future.wait(
        memories.map((memory) async {
          try {
            return MapEntry(
              memory.id,
              (await CommentsRepository.fetchForMemory(memory.id)).length,
            );
          } catch (_) {
            return MapEntry(memory.id, 0);
          }
        }),
      );

      final likeCounts = await likeCountsFuture;
      final commentResults = await commentResultsFuture;
      final commentCounts = <String, int>{
        for (final entry in commentResults) entry.key: entry.value,
      };

      setState(() {
        _memories = memories;
        _likeCounts = likeCounts;
        _commentCounts = commentCounts;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('DiscoverScreen: load failed: $e\\n$st');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openMemory(Memory memory) async {
    final item = MemoryItem(
      id: memory.id,
      title: memory.title,
      date:
          '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}',
      imageUrl: memory.imageUrl,
      semanticLabel: 'Public memory photo',
      circle: 'Public',
      circleColor: AppTheme.cyanAccent,
      privacy: MemoryPrivacy.public,
      type: MemoryType.photo,
    );
    final deleted = await context.push<bool>(
      AppRoutes.memoryDetailScreen,
      extra: item,
    );
    if (deleted == true && mounted) {
      await _load();
    }
  }

  Widget _modePill({
    required _DiscoverMode mode,
    required String label,
  }) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : AppTheme.surfaceVariantDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppTheme.primaryGreen
                : AppTheme.outline.withAlpha(90),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.black : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBody: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryGreen,
              backgroundColor: AppTheme.surfaceDark,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: top + 12)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discover',
                                  style: GoogleFonts.manrope(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Moments worth remembering, from\\naround the world.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariantDark,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.textPrimary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _modePill(
                            mode: _DiscoverMode.forYou,
                            label: 'For You',
                          ),
                          const SizedBox(width: 7),
                          _modePill(
                            mode: _DiscoverMode.nearby,
                            label: 'Nearby',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  if (_loadFailed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 60,
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Couldn't load Discover right now.",
                              style: GoogleFonts.manrope(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_memories.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 70,
                        ),
                        child: Text(
                          _mode == _DiscoverMode.nearby
                              ? 'No nearby public memories with location data yet.'
                              : 'Public memories will appear here when people share them.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final memory = _memories[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PublicMemoryCard(
                                memory: memory,
                                likeCount: _likeCounts[memory.id] ?? 0,
                                commentCount: _commentCounts[memory.id] ?? 0,
                                onTap: () => _openMemory(memory),
                              ),
                            );
                          },
                          childCount: _memories.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 100,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PublicMemoryCard extends StatelessWidget {
  final Memory memory;
  final int likeCount;
  final int commentCount;
  final VoidCallback onTap;

  const _PublicMemoryCard({
    required this.memory,
    required this.likeCount,
    required this.commentCount,
    required this.onTap,
  });

  String _timeAgo() {
    final difference = DateTime.now().difference(memory.createdAt);
    if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${memory.createdAt.day}/${memory.createdAt.month}/${memory.createdAt.year}';
  }

  String? _captionPreview() {
    final caption = memory.caption?.trim() ?? '';
    if (caption.isEmpty) return null;
    final words = caption.split(RegExp(r'\s+'));
    if (words.length <= 9) return caption;
    return '${words.take(9).join(' ')}…';
  }

  @override
  Widget build(BuildContext context) {
    final title = memory.title.trim().isEmpty ? 'A shared memory' : memory.title.trim();
    final description = _captionPreview();
    final contributor = memory.contributor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surfaceVariantDark),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.12,
                  child: CachedNetworkImage(
                    imageUrl: memory.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.surfaceVariantDark),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surfaceVariantDark,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                if (memory.location?.trim().isNotEmpty == true)
                  Positioned(
                    left: 12,
                    bottom: 10,
                    right: 12,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            memory.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppTheme.surfaceVariantDark,
                        backgroundImage: contributor?.avatarUrl?.isNotEmpty == true
                            ? CachedNetworkImageProvider(contributor!.avatarUrl!)
                            : null,
                        child: contributor?.avatarUrl?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.person_outline, size: 17, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          contributor?.displayName ?? 'Sprout member',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(),
                        style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          description,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            height: 1.45,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        if ((memory.caption?.trim().split(RegExp(r'\s+')).length ?? 0) > 9)
                          InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
                              child: Text(
                                'See more',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 15, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$likeCount',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$commentCount',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryGreen),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
