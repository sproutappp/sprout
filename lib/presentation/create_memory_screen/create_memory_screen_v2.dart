import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/circle.dart';
import '../../models/profile.dart';
import '../../services/circles_repository.dart';
import '../../services/memory_people_repository.dart';
import '../../services/memories_repository.dart';
import '../../theme/app_theme.dart';

class CreateMemoryScreenV2 extends StatefulWidget {
  final String? initialCircleId;
  const CreateMemoryScreenV2({super.key, this.initialCircleId});

  @override
  State<CreateMemoryScreenV2> createState() => _CreateMemoryScreenV2State();
}

class _CreateMemoryScreenV2State extends State<CreateMemoryScreenV2> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _picker = ImagePicker();
  final Geocoding _geocoding = Geocoding();
  final Set<String> _circleIds = {};
  final Set<String> _taggedPeople = {};
  List<Circle> _circles = [];
  List<Profile> _people = [];
  File? _image;
  bool _public = false;
  bool _loading = true;
  bool _loadingPeople = false;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCircleId != null) _circleIds.add(widget.initialCircleId!);
    _loadCircles();
    _locate();
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
        _loading = false;
      });
      await _loadPeople();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPeople() async {
    if (_public || _circleIds.isEmpty) {
      if (mounted) {
        setState(() {
          _people = [];
          _taggedPeople.clear();
          _loadingPeople = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingPeople = true);
    try {
      final people = await CirclesRepository.fetchMembersForCircles(_circleIds.toList());
      final ids = people.map((p) => p.id).toSet();
      if (!mounted) return;
      setState(() {
        _people = people;
        _taggedPeople.removeWhere((id) => !ids.contains(id));
        _loadingPeople = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _people = [];
        _loadingPeople = false;
      });
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 2048, imageQuality: 88);
      if (picked != null && mounted) {
        setState(() {
          _image = File(picked.path);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access your photos.");
    }
  }

  Future<void> _locate() async {
    if (mounted) setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final places = await _geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
      if (!mounted || places.isEmpty) return;
      final p = places.first;
      final parts = <String>[
        if ((p.name ?? '').isNotEmpty) p.name!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      if (_location.text.trim().isEmpty && parts.isNotEmpty) _location.text = parts.join(', ');
    } catch (_) {
      // Location is optional; leave the field empty if reverse geocoding fails.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_image == null) {
      setState(() => _error = 'Add a photo before saving.');
      return;
    }
    if (!_public && _circleIds.isEmpty) {
      setState(() => _error = 'Choose at least one circle, or make it public.');
      return;
    }
    setState(() => _saving = true);
    try {
      final combined = [_title.text.trim(), _caption.text.trim()].where((s) => s.isNotEmpty).join(' — ');
      final memory = await MemoriesRepository.addMemory(
        file: _image!,
        caption: combined.isEmpty ? null : combined,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        isPublic: _public,
        circleIds: _public ? const [] : _circleIds.toList(),
      );
      if (!_public && _taggedPeople.isNotEmpty) {
        await MemoryPeopleRepository.replaceForMemory(
          memoryId: memory.id,
          personIds: _taggedPeople.toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save this memory. Please try again.";
        });
      }
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
        title: Text('New Memory', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 30),
              children: [
                _photoPicker(),
                const SizedBox(height: 24),
                _field('Memory Title', _title, 'Give this memory a name'),
                const SizedBox(height: 18),
                _field('Caption', _caption, 'What happened?', maxLines: 4),
                const SizedBox(height: 18),
                _locationField(),
                const SizedBox(height: 24),
                Text('Share with', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Anyone on Sprout can see this memory', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  value: _public,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (v) async {
                    setState(() {
                      _public = v;
                      if (v) _circleIds.clear();
                    });
                    await _loadPeople();
                  },
                ),
                if (!_public) ...[
                  const SizedBox(height: 4),
                  Text('Circles', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ..._circles.map((c) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primaryGreen,
                    title: Text(c.name, style: const TextStyle(color: AppTheme.textPrimary)),
                    value: _circleIds.contains(c.id),
                    onChanged: (v) async {
                      setState(() {
                        if (v == true) {
                          _circleIds.add(c.id);
                        } else {
                          _circleIds.remove(c.id);
                        }
                      });
                      await _loadPeople();
                    },
                  )),
                  const SizedBox(height: 14),
                  Text('Tag People', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Tag people who are members of the selected circles.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (_loadingPeople)
                    const LinearProgressIndicator(minHeight: 2, color: AppTheme.primaryGreen)
                  else
                    ..._people.map((p) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryGreen,
                      title: Text(p.displayName, style: const TextStyle(color: AppTheme.textPrimary)),
                      value: _taggedPeople.contains(p.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _taggedPeople.add(p.id);
                        } else {
                          _taggedPeople.remove(p.id);
                        }
                      }),
                    )),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
                        : const Text('Save Memory', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _photoPicker() => Container(
    height: 250,
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.outline)),
    clipBehavior: Clip.antiAlias,
    child: _image == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, size: 42, color: AppTheme.primaryGreen),
              const SizedBox(height: 12),
              const Text('Add a photo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera')),
                  OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
                ],
              ),
            ],
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_image!, fit: BoxFit.cover),
              Positioned(top: 12, right: 12, child: IconButton.filled(onPressed: () => setState(() => _image = null), icon: const Icon(Icons.close_rounded))),
            ],
          ),
  );

  Widget _locationField() => TextField(
    controller: _location,
    style: const TextStyle(color: AppTheme.textPrimary),
    decoration: InputDecoration(
      labelText: 'Location',
      labelStyle: const TextStyle(color: AppTheme.textMuted),
      hintText: _locating ? 'Finding location...' : 'Optional location',
      hintStyle: const TextStyle(color: AppTheme.textDisabled),
      prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.textMuted),
      suffixIcon: IconButton(onPressed: _locating ? null : _locate, icon: const Icon(Icons.my_location_rounded, color: AppTheme.primaryGreen)),
      filled: true,
      fillColor: AppTheme.cardDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outline)),
    ),
  );

  Widget _field(String label, TextEditingController controller, String hint, {int maxLines = 1}) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: AppTheme.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textMuted),
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textDisabled),
      filled: true,
      fillColor: AppTheme.cardDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryGreen)),
    ),
  );
}
