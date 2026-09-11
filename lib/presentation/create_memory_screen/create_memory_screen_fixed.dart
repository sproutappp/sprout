import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/circle.dart';
import '../../models/profile.dart';
import '../../services/circles_repository.dart';
import '../../services/memories_repository.dart';
import '../../theme/app_theme.dart';

class CreateMemoryScreenFixed extends StatefulWidget {
  final String? initialCircleId;
  const CreateMemoryScreenFixed({super.key, this.initialCircleId});

  @override
  State<CreateMemoryScreenFixed> createState() => _CreateMemoryScreenFixedState();
}

class _CreateMemoryScreenFixedState extends State<CreateMemoryScreenFixed> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _picker = ImagePicker();

  File? _image;
  List<Circle> _circles = [];
  List<Profile> _people = [];
  final Set<String> _selectedCircles = {};
  final Set<String> _taggedPeople = {};
  bool _loadingCircles = true;
  bool _loadingPeople = false;
  bool _locating = false;
  bool _saving = false;
  String? _error;
  bool _public = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCircleId != null) _selectedCircles.add(widget.initialCircleId!);
    _loadCircles();
    _captureLocation();
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadCircles() async {
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() {
        _circles = circles;
        if (_selectedCircles.isEmpty && circles.isNotEmpty) {
          _selectedCircles.add(circles.first.id);
        }
        _loadingCircles = false;
      });
      await _loadPeople();
    } catch (e) {
      if (mounted) setState(() { _loadingCircles = false; _error = 'Could not load your circles.'; });
    }
  }

  Future<void> _loadPeople() async {
    if (_public || _selectedCircles.isEmpty) {
      if (mounted) setState(() { _people = []; _loadingPeople = false; });
      return;
    }
    setState(() => _loadingPeople = true);
    try {
      final people = await CirclesRepository.fetchMembersForCircles(_selectedCircles.toList());
      if (!mounted) return;
      final validIds = people.map((p) => p.id).toSet();
      setState(() {
        _people = people;
        _taggedPeople.removeWhere((id) => !validIds.contains(id));
        _loadingPeople = false;
      });
    } catch (_) {
      if (mounted) setState(() { _people = []; _loadingPeople = false; });
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final places = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted || places.isEmpty) return;
      final p = places.first;
      final parts = <String>[
        if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty) p.administrativeArea!.trim(),
      ];
      if (parts.isNotEmpty) _location.text = parts.join(', ');
    } catch (_) {
      // Location is optional. Leave the field blank on any denial/failure.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2048, imageQuality: 85);
    if (picked != null && mounted) setState(() => _image = File(picked.path));
  }

  Future<void> _save() async {
    if (_image == null) return setState(() => _error = 'Add a photo before saving.');
    if (!_public && _selectedCircles.isEmpty) {
      return setState(() => _error = 'Choose at least one circle to share this with.');
    }
    setState(() { _saving = true; _error = null; });
    try {
      final title = _title.text.trim();
      final caption = _caption.text.trim();
      final combined = [title, caption].where((s) => s.isNotEmpty).join(' — ');
      await MemoriesRepository.addMemory(
        file: _image!,
        caption: combined.isEmpty ? null : combined,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        isPublic: _public,
        circleIds: _public ? const [] : _selectedCircles.toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save memory: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('Create Memory')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 32),
        children: [
          _image == null
              ? Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
                ])
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(children: [
                    Image.file(_image!, height: 240, width: double.infinity, fit: BoxFit.cover),
                    Positioned(top: 10, right: 10, child: IconButton(onPressed: () => setState(() => _image = null), icon: const Icon(Icons.close), style: IconButton.styleFrom(backgroundColor: Colors.black54))),
                  ]),
                ),
          const SizedBox(height: 24),
          _field(_title, 'Memory Title', 'Give this memory a name'),
          const SizedBox(height: 16),
          _field(_caption, 'Caption', 'What happened?', maxLines: 3),
          const SizedBox(height: 16),
          Text('Location', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _location,
            decoration: InputDecoration(
              hintText: _locating ? 'Finding your location…' : 'Add location',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: _locating ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(onPressed: _captureLocation, icon: const Icon(Icons.my_location)),
            ),
          ),
          const SizedBox(height: 24),
          Text('Share with', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Public memory'),
            subtitle: const Text('Anyone can discover it'),
            value: _public,
            onChanged: (value) async {
              setState(() => _public = value);
              await _loadPeople();
            },
          ),
          if (!_public) ...[
            const SizedBox(height: 8),
            if (_loadingCircles)
              const Center(child: CircularProgressIndicator())
            else if (_circles.isEmpty)
              const Text("You don't have any circles yet — create one first." )
            else ...[
              const Text('Choose one or more circles'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final circle in _circles)
                  FilterChip(
                    label: Text(circle.name),
                    selected: _selectedCircles.contains(circle.id),
                    onSelected: (selected) async {
                      setState(() {
                        if (selected) { _selectedCircles.add(circle.id); } else { _selectedCircles.remove(circle.id); }
                      });
                      await _loadPeople();
                    },
                  ),
              ]),
            ],
            const SizedBox(height: 22),
            Text('Tag People', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (_loadingPeople)
              const Center(child: CircularProgressIndicator())
            else if (_people.isEmpty)
              const Text('No User in Circle')
            else
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final person in _people)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_taggedPeople.contains(person.id)) { _taggedPeople.remove(person.id); } else { _taggedPeople.add(person.id); }
                    }),
                    child: SizedBox(width: 64, child: Column(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: person.avatarUrl == null ? null : NetworkImage(person.avatarUrl!),
                        child: person.avatarUrl == null ? const Icon(Icons.person_outline) : null,
                      ),
                      const SizedBox(height: 4),
                      Text(person.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _taggedPeople.contains(person.id) ? AppTheme.primaryGreen : AppTheme.textSecondary, fontSize: 11)),
                    ])),
                  ),
              ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 18),
            Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          SizedBox(height: 52, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('Save Memory'))),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(hintText: hint)),
    ]);
  }
}
