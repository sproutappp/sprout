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

      // The memory has already been created successfully at this point.
      // Tagging is a follow-up operation; a failure here must not make the
      // user retry the whole save and create duplicate memories.
      if (!_public && _taggedPeople.isNotEmpty) {
        try {
          await MemoryPeopleRepository.replaceForMemory(
            memoryId: memory.id,
            personIds: _taggedPeople.toList(),
          );
        } catch (_) {
          // Keep the successful memory creation intact. The tag operation
          // should not turn a completed save into a false failure.
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save this memory — try again.";
        });
      }
    }
  }
