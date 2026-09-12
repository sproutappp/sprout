import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/circle.dart';
import '../models/profile.dart';
import '../services/circles_repository.dart';
import '../services/profiles_repository.dart';
import '../theme/app_theme.dart';

class CircleActionMenu extends StatelessWidget {
  final Circle circle;
  final VoidCallback? onChanged;

  const CircleActionMenu({super.key, required this.circle, this.onChanged});

  Future<void> _open(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CircleActionSheet(circleName: circle.name),
    );
    if (!context.mounted || action == null) return;
    if (action == 'invite') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CircleInvitePicker(circle: circle),
      );
    } else if (action == 'share') {
      try {
        final token = await CirclesRepository.createInvite(circle.id);
        final link = 'https://sproutapp.in/join/$token';
        await Share.share('Join my ${circle.name} circle on Sprout:\n$link');
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the invite link.")),
        );
      }
    } else if (action == 'edit') {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CircleEditForm(circle: circle),
      );
      if (saved == true) onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Circle options',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(Icons.more_vert_rounded, size: 21, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _CircleActionSheet extends StatelessWidget {
  final String circleName;
  const _CircleActionSheet({required this.circleName});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return _SheetContainer(
      bottomPadding: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(circleName, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Circle options', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 20),
          _MenuOption(icon: Icons.person_add_rounded, label: 'Invite', color: AppTheme.primaryGreen, onTap: () => Navigator.pop(context, 'invite')),
          _MenuOption(icon: Icons.share_rounded, label: 'Share', color: AppTheme.cyanAccent, onTap: () => Navigator.pop(context, 'share')),
          _MenuOption(icon: Icons.edit_rounded, label: 'Edit Circle', color: AppTheme.textPrimary, onTap: () => Navigator.pop(context, 'edit')),
        ],
      ),
    );
  }
}

class _CircleInvitePicker extends StatefulWidget {
  final Circle circle;
  const _CircleInvitePicker({required this.circle});

  @override
  State<_CircleInvitePicker> createState() => _CircleInvitePickerState();
}

class _CircleInvitePickerState extends State<_CircleInvitePicker> {
  List<Profile> _users = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final all = await ProfilesRepository.fetchAllUsers();
      final memberIds = await CirclesRepository.fetchMemberIds(widget.circle.id);
      final currentId = CirclesRepository.currentUserId;
      final members = memberIds.toSet();
      if (!mounted) return;
      setState(() {
        _users = all.where((u) => u.id != currentId && !members.contains(u.id)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load people. Try again.";
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final count = await CirclesRepository.sendCircleInvites(
        circleId: widget.circle.id,
        userIds: _selected.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count invite${count == 1 ? '' : 's'} sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send invites. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return _SheetContainer(
      bottomPadding: bottom + keyboard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite people', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Select Sprout users to invite to ${widget.circle.name}.', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 18),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)))
          else if (_error != null)
            Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.error))
          else if (_users.isEmpty)
            Text('No other Sprout users to invite right now.', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final user = _users[index];
                  final selected = _selected.contains(user.id);
                  return GestureDetector(
                    onTap: _sending ? null : () => setState(() => selected ? _selected.remove(user.id) : _selected.add(user.id)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryGreenGlow : AppTheme.surfaceVariantDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppTheme.primaryGreen.withAlpha(100) : AppTheme.outline),
                      ),
                      child: Row(
                        children: [
                          _Avatar(url: user.avatarUrl),
                          const SizedBox(width: 12),
                          Expanded(child: Text(user.displayName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppTheme.primaryGreen : AppTheme.textDisabled, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty || _sending ? null : _send,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(_selected.isEmpty ? 'Send Invite' : 'Send Invite (${_selected.length})', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleEditForm extends StatefulWidget {
  final Circle circle;
  const _CircleEditForm({required this.circle});

  @override
  State<_CircleEditForm> createState() => _CircleEditFormState();
}

class _CircleEditFormState extends State<_CircleEditForm> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  File? _cover;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.circle.name);
    _description = TextEditingController(text: widget.circle.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _cover = File(picked.path));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a circle name.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await CirclesRepository.updateCircle(circleId: widget.circle.id, name: name, description: _description.text.trim().isEmpty ? null : _description.text.trim(), coverFile: _cover);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save circle — try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return _SheetContainer(
      bottomPadding: bottom + keyboard,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Circle', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Update your circle details', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 22),
            const _FieldLabel('Circle name'),
            const SizedBox(height: 8),
            _FormField(controller: _name, hint: 'Circle name', icon: Icons.group_rounded),
            const SizedBox(height: 16),
            const _FieldLabel('Description (optional)'),
            const SizedBox(height: 8),
            _FormField(controller: _description, hint: "What's this circle about?", icon: Icons.notes_rounded, maxLines: 2),
            const SizedBox(height: 20),
            const _FieldLabel('Circle cover'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _saving ? null : _pickCover,
              child: Container(
                height: 150,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppTheme.surfaceVariantDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.outline, width: 0.8)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cover != null)
                      Image.file(_cover!, fit: BoxFit.cover)
                    else if (widget.circle.coverImageUrl?.isNotEmpty == true)
                      CachedNetworkImage(imageUrl: widget.circle.coverImageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _coverPlaceholder())
                    else
                      _coverPlaceholder(),
                    Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withAlpha(170), borderRadius: BorderRadius.circular(10)), child: Text('Change', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text('Save', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)))),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(color: AppTheme.surfaceVariantDark, child: const Center(child: Icon(Icons.add_photo_alternate_rounded, size: 34, color: AppTheme.textDisabled)));
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({required this.url});
  @override
  Widget build(BuildContext context) {
    return Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.outline)), child: ClipOval(child: url?.isNotEmpty == true ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _placeholder()) : _placeholder()));
  }
  Widget _placeholder() => Container(color: AppTheme.surfaceVariantDark, child: const Icon(Icons.person_rounded, size: 20, color: AppTheme.textDisabled));
}

class _SheetContainer extends StatelessWidget {
  final double bottomPadding;
  final Widget child;
  const _SheetContainer({required this.bottomPadding, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16), decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.outline, width: 0.5)), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 20), width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))), child]));
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuOption({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(onTap: onTap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: AppTheme.surfaceVariantDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.outline, width: 0.6)), child: Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 12), Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: color))]))));
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.3));
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  const _FormField({required this.controller, required this.hint, required this.icon, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: AppTheme.surfaceVariantDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.outline, width: 0.8)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: EdgeInsets.fromLTRB(14, maxLines > 1 ? 14 : 0, 0, 0), child: Icon(icon, size: 18, color: AppTheme.textDisabled)), Expanded(child: TextField(controller: controller, maxLines: maxLines, style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textPrimary), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textDisabled), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true)))]));
  }
}
