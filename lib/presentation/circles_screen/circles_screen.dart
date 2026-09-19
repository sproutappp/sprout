import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/circle.dart';
import '../../routes/app_routes.dart';
import '../../services/circles_repository.dart';
import '../../services/notifications_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/circle_action_menu.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});
  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  List<Circle> _circles = [];
  bool _loading = true;
  String? _error;
  int _unreadMemoryCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationsRepository.fetchUnreadCircleMemoryCount();
      if (mounted) setState(() => _unreadMemoryCount = count);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() { _circles = circles; _loading = false; });
    } catch (e, st) {
      debugPrint('CirclesScreen: fetchMyCircles failed: $e\n$st');
      if (!mounted) return;
      setState(() { _error = "Couldn't load your circles. Pull down to try again."; _loading = false; });
    }
  }

  Future<void> _openCreateCircle() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateCircleSheet(),
    );
    if (id == null || !mounted) return;
    await _load();
    if (mounted) context.push(AppRoutes.circleDetailScreen, extra: id);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.3, colors: [Color(0xFF0D1A10), Color(0xFF0A0F0D)]),
        ),
        child: RefreshIndicator(
          color: AppTheme.primaryGreen,
          backgroundColor: AppTheme.surfaceDark,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your Circles', style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('The people you share memories with', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.joinCircleScreen),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.link_rounded, size: 14, color: AppTheme.primaryGreen),
                            const SizedBox(width: 5),
                            Text('Have an invite link? Join a circle', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                          ]),
                        ),
                      ])),
                      if (_circles.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openCreateCircle,
                          child: Container(width: 42, height: 42, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add_rounded, size: 22, color: Colors.black)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (_unreadMemoryCount > 0)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _NewMemoriesBanner(count: _unreadMemoryCount, onTap: () => context.push(AppRoutes.notificationsScreen)))),
              if (_unreadMemoryCount > 0) const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (_loading)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2))))
              else if (_error != null)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)))) )
              else if (_circles.isEmpty)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 60, 20, 0), child: _EmptyCircles(onCreate: _openCreateCircle)))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                    final circle = _circles[index];
                    return Padding(padding: const EdgeInsets.only(bottom: 14), child: _CircleCard(circle: circle, onChanged: _load));
                  }, childCount: _circles.length)),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  final Circle circle;
  final VoidCallback onChanged;
  const _CircleCard({required this.circle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryGreen.withAlpha(45), width: 0.8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(AppRoutes.circleDetailScreen, extra: circle.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: circle.coverImageUrl?.isNotEmpty == true
                  ? CachedNetworkImage(imageUrl: circle.coverImageUrl!, width: 64, height: 64, fit: BoxFit.cover, errorWidget: (_, __, ___) => _coverPlaceholder())
                  : _coverPlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(circle.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [const Icon(Icons.people_rounded, size: 12, color: AppTheme.textDisabled), const SizedBox(width: 4), Text('${circle.memberCount} members', style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textMuted))]),
              if (circle.description?.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(circle.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
              ],
            ])),
            const SizedBox(width: 2),
            // Keep the three-dot hit target visually aligned with every card.
            CircleActionMenu(circle: circle, onChanged: onChanged),
          ]),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(width: 64, height: 64, color: AppTheme.surfaceVariantDark, child: const Icon(Icons.group_rounded, size: 28, color: AppTheme.textDisabled));
}

class _NewMemoriesBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NewMemoriesBanner({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: AppTheme.primaryGreen.withAlpha(18), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryGreen.withAlpha(55))), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.black)), const SizedBox(width: 12), Expanded(child: Text(count == 1 ? '1 new memory across your circles' : '$count new memories across your circles', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))), const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.primaryGreen)])));
}

class _EmptyCircles extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyCircles({required this.onCreate});
  @override
  Widget build(BuildContext context) => Column(children: [const Icon(Icons.groups_rounded, size: 44, color: AppTheme.textDisabled), const SizedBox(height: 14), Text('No circles yet', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)), const SizedBox(height: 6), Text('Create a private space for the people you share memories with.', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onCreate, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text('Create Circle', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700)))]) );
}

class _CreateCircleSheet extends StatefulWidget {
  const _CreateCircleSheet();
  @override
  State<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<_CreateCircleSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  File? _cover;
  bool _creating = false;
  @override
  void dispose() { _name.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _cover = File(picked.path));
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a circle name.'))); return; }
    if (_cover == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a circle cover image.'))); return; }
    setState(() => _creating = true);
    try {
      final circle = await CirclesRepository.createCircle(name: name, description: _description.text.trim().isEmpty ? null : _description.text.trim(), coverFile: _cover);
      if (mounted) Navigator.pop(context, circle.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't create circle — try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom;
    return Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 16), decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.outline, width: 0.5)), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 20), width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))), Text('Create a Circle', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)), const SizedBox(height: 4), Text('A private space for your trusted people', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 22), _Label('Circle name'), const SizedBox(height: 8), _Field(controller: _name, hint: 'e.g. Family, College Friends...', icon: Icons.group_rounded), const SizedBox(height: 16), _Label('Description (optional)'), const SizedBox(height: 8), _Field(controller: _description, hint: "What's this circle about?", icon: Icons.notes_rounded, maxLines: 2), const SizedBox(height: 18), _Label('Circle cover'), const SizedBox(height: 8), GestureDetector(onTap: _creating ? null : _pickCover, child: Container(height: 150, width: double.infinity, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppTheme.surfaceVariantDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.outline)), child: _cover == null ? const Center(child: Icon(Icons.add_photo_alternate_rounded, size: 34, color: AppTheme.textDisabled)) : Image.file(_cover!, fit: BoxFit.cover))), const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _creating ? null : _create, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text('Create Circle', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700))) )])));
  }
}

class _Label extends StatelessWidget { final String text; const _Label(this.text); @override Widget build(BuildContext context) => Text(text, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)); }

class _Field extends StatelessWidget {
  final TextEditingController controller; final String hint; final IconData icon; final int maxLines;
  const _Field({required this.controller, required this.hint, required this.icon, this.maxLines = 1});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: AppTheme.surfaceVariantDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.outline, width: 0.8)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: EdgeInsets.fromLTRB(14, maxLines > 1 ? 14 : 0, 0, 0), child: Icon(icon, size: 18, color: AppTheme.textDisabled)), Expanded(child: TextField(controller: controller, maxLines: maxLines, style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textPrimary), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textDisabled), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true))) ]));
}
