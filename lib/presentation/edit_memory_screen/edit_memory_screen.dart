import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/circle.dart';
import '../../models/profile.dart';
import '../../services/circles_repository.dart';
import '../../services/memory_edit_repository.dart';
import '../../services/memory_people_repository.dart';
import '../../theme/app_theme.dart';

class EditMemoryScreen extends StatefulWidget {
  final String memoryId;
  final bool openCirclePicker;

  const EditMemoryScreen({
    super.key,
    required this.memoryId,
    this.openCirclePicker = false,
  });

  @override
  State<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends State<EditMemoryScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();

  List<Circle> _circles = [];
  List<Profile> _people = [];
  final Set<String> _selectedCircleIds = {};
  final Set<String> _taggedPeople = {};
  bool _isPublic = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final memory = await MemoryEditRepository.fetchMemory(widget.memoryId);
      if (memory == null) throw StateError('Memory not found');

      final circles = await CirclesRepository.fetchMyCircles();
      final circleIds = await MemoryEditRepository.fetchCircleIds(widget.memoryId);
      final people = circleIds.isEmpty
          ? <Profile>[]
          : await CirclesRepository.fetchMembersForCircles(circleIds);
      final tagged = await MemoryPeopleRepository.fetchForMemory(widget.memoryId);

      if (!mounted) return;
      final storedCaption = (memory['caption'] as String? ?? '').trim();
      final separator = storedCaption.indexOf(' — ');
      _titleController.text = separator > 0
          ? storedCaption.substring(0, separator)
          : storedCaption;
      _captionController.text = separator > 0
          ? storedCaption.substring(separator + 3)
          : '';
      _locationController.text = memory['location'] as String? ?? '';
      _isPublic = memory['is_public'] == true;
      _selectedCircleIds.addAll(circleIds);
      _taggedPeople.addAll(tagged.map((p) => p.id));

      setState(() {
        _circles = circles;
        _people = people;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _refreshPeople() async {
    if (_isPublic || _selectedCircleIds.isEmpty) {
      setState(() {
        _people = [];
        _taggedPeople.clear();
      });
      return;
    }
    final people = await CirclesRepository.fetchMembersForCircles(
      _selectedCircleIds.toList(),
    );
    final valid = people.map((p) => p.id).toSet();
    setState(() {
      _people = people;
      _taggedPeople.removeWhere((id) => !valid.contains(id));
    });
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_isPublic && _selectedCircleIds.isEmpty) {
      setState(() => _error = 'Choose at least one circle for a private memory.');
      return;
    }

    setState(() => _saving = true);
    try {
      final title = _titleController.text.trim();
      final caption = _captionController.text.trim();
      final combined = [title, caption].where((s) => s.isNotEmpty).join(' — ');

      await MemoryEditRepository.updateMemory(
        memoryId: widget.memoryId,
        caption: combined,
        location: _locationController.text,
        isPublic: _isPublic,
        circleIds: _selectedCircleIds.toList(),
      );

      await MemoryPeopleRepository.replaceForMemory(
        memoryId: widget.memoryId,
        personIds: _isPublic ? const [] : _taggedPeople.toList(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save changes. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: AppTheme.textPrimary,
        title: Text('Edit Memory', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _error != null && _titleController.text.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: AppTheme.textMuted))))
              : ListView(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 32),
                  children: [
                    _field('Memory Title', _titleController, 'Give this memory a name'),
                    const SizedBox(height: 18),
                    _field('Caption', _captionController, 'What happened?', maxLines: 4),
                    const SizedBox(height: 18),
                    _field('Location', _locationController, 'Optional location'),
                    const SizedBox(height: 26),
                    Text('Share with', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Public', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Anyone on Sprout can see this memory', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      value: _isPublic,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (value) async {
                        setState(() {
                          _isPublic = value;
                          if (value) _selectedCircleIds.clear();
                        });
                        await _refreshPeople();
                      },
                    ),
                    if (!_isPublic) ...[
                      const SizedBox(height: 8),
                      Text('Circles', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (_circles.isEmpty)
                        const Text('Create a circle first.', style: TextStyle(color: AppTheme.textMuted))
                      else
                        ..._circles.map((circle) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _selectedCircleIds.contains(circle.id),
                              activeColor: AppTheme.primaryGreen,
                              title: Text(circle.name, style: const TextStyle(color: AppTheme.textPrimary)),
                              onChanged: (checked) async {
                                setState(() {
                                  if (checked == true) {
                                    _selectedCircleIds.add(circle.id);
                                  } else {
                                    _selectedCircleIds.remove(circle.id);
                                  }
                                });
                                await _refreshPeople();
                              },
                            )),
                      const SizedBox(height: 16),
                      Text('Tag People', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('People from the selected circles can be tagged.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 8),
                      if (_people.isEmpty)
                        const Text('No people available for the selected circles.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                      else
                        ..._people.map((person) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _taggedPeople.contains(person.id),
                              activeColor: AppTheme.primaryGreen,
                              title: Text(person.displayName, style: const TextStyle(color: AppTheme.textPrimary)),
                              secondary: CircleAvatar(
                                backgroundImage: person.avatarUrl == null ? null : NetworkImage(person.avatarUrl!),
                                child: person.avatarUrl == null ? Text(person.displayName.characters.first.toUpperCase()) : null,
                              ),
                              onChanged: (checked) => setState(() {
                                if (checked == true) {
                                  _taggedPeople.add(person.id);
                                } else {
                                  _taggedPeople.remove(person.id);
                                }
                              }),
                            )),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.black),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textDisabled),
            filled: true,
            fillColor: AppTheme.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outline)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outline)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryGreen)),
          ),
        ),
      ],
    );
  }
}
