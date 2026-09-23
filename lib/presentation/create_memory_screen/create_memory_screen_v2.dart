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
  final List<File> _images = [];
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
      if (mounted) {
        setState(() {
          _people = [];
          _loadingPeople = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 2048,
        imageQuality: 88,
      );
      if (!mounted || picked.isEmpty) return;
      final existing = _images.map((file) => file.path).toSet();
      final additions = picked
          .map((file) => File(file.path))
          .where((file) => !existing.contains(file.path))
          .toList();
      if (additions.isEmpty) return;
      setState(() {
        _images.addAll(additions);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access your photos.");
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        imageQuality: 88,
      );
      if (picked != null && mounted) {
        setState(() {
          _images.add(File(picked.path));
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't access your camera.");
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_images.isEmpty) _error = null;
    });
  }

  Future<void> _locate() async {
    if (mounted) setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
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
      // Location is optional.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = null);
    if (_images.isEmpty) {
      setState(() => _error = 'Add at least one photo before saving.');
      return;
    }
    if (!_public && _circleIds.isEmpty) {
      setState(() => _error = 'Choose at least one circle, or make it public.');
      return;
    }
    setState(() => _saving = true);
    try {
      final title = _title.text.trim();
      final caption = _caption.text.trim();
      final memory = await MemoriesRepository.addMemory(
        files: List<File>.unmodifiable(_images),
        title: title.isEmpty ? null : title,
        caption: caption.isEmpty ? null : caption,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        isPublic: _public,
        circleIds: _public ? const [] : _circleIds.toList(),
      );

      if (!_public && _taggedPeople.isNotEmpty) {
        try {
          await MemoryPeopleRepository.replaceForMemory(
            memoryId: memory.id,
            personIds: _taggedPeople.toList(),
          );
        } catch (_) {
          // Keep the successful memory creation intact. Tagging is separate
          // from the memory save and must not cause a duplicate retry.
        }
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

  Widget _circleSelector() {
    if (_circles.isEmpty) {
      return const Text(
        "You don't have any circles yet — create one first.",
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a Circle', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _circles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final circle = _circles[index];
              final selected = _circleIds.contains(circle.id);
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    if (selected) {
                      _circleIds.remove(circle.id);
                    } else {
                      _circleIds.add(circle.id);
                    }
                  });
                  await _loadPeople();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryGreen.withAlpha(28) : const Color(0xFF0D2116),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? AppTheme.primaryGreen.withAlpha(170) : AppTheme.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CircleCover(circle: circle),
                      const SizedBox(width: 7),
                      Text(circle.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? AppTheme.primaryGreen : AppTheme.textSecondary)),
                      if (selected) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.check_rounded, size: 14, color: AppTheme.primaryGreen),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _peopleTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tag People', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Tag people who are members of the selected circles.', style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        if (_loadingPeople)
          const SizedBox(height: 64, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)))
        else if (_people.isEmpty)
          Text('No User in Circle', style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.textMuted))
        else
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final person = _people[index];
                final selected = _taggedPeople.contains(person.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _taggedPeople.remove(person.id);
                    } else {
                      _taggedPeople.add(person.id);
                    }
                  }),
                  child: SizedBox(
                    width: 58,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? AppTheme.primaryGreen : Colors.transparent, width: 2)),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.surfaceVariantDark,
                                backgroundImage: person.avatarUrl?.isNotEmpty == true ? NetworkImage(person.avatarUrl!) : null,
                                child: person.avatarUrl?.isNotEmpty == true ? null : const Icon(Icons.person_outline, color: AppTheme.textDisabled),
                              ),
                              if (selected)
                                Positioned(
                                  right: -2,
                                  bottom: -1,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.black),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(person.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w600, color: selected ? AppTheme.primaryGreen : AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
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
          TextButton(onPressed: _saving ? null : _save, child: Text('Save', style: GoogleFonts.manrope(fontWeight: FontWeight.w800))),
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
                  const SizedBox(height: 8),
                  _circleSelector(),
                  const SizedBox(height: 22),
                  _peopleTagSection(),
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

  Widget _photoPicker() {
    if (_images.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.outline)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, size: 42, color: AppTheme.primaryGreen),
            const SizedBox(height: 12),
            const Text('Add photos', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Select one or multiple photos for this memory', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(onPressed: _pickFromCamera, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera')),
                OutlinedButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.outline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(aspectRatio: 1.35, child: Image.file(_images.first, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${_images.length} ${_images.length == 1 ? 'photo' : 'photos'}', style: GoogleFonts.manrope(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.add_photo_alternate_outlined, size: 17), label: const Text('Add more')),
            ],
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(width: 72, height: 72, child: Image.file(_images[index], fit: BoxFit.cover)),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          width: 21,
                          height: 21,
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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

class _CircleCover extends StatelessWidget {
  final Circle circle;
  const _CircleCover({required this.circle});

  @override
  Widget build(BuildContext context) {
    final url = circle.coverImageUrl?.trim();
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceVariantDark, border: Border.all(color: AppTheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? const Icon(Icons.groups_rounded, size: 14, color: AppTheme.textMuted)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.groups_rounded, size: 14, color: AppTheme.textMuted)),
    );
  }
}
