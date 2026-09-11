import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _CreateMemoryScreenFixedState extends State<CreateMemoryScreenFixed>
    with SingleTickerProviderStateMixin {
  static const _circleColors = [
    Color(0xFFFF8C39),
    Color(0xFF00E5FF),
    Color(0xFF39FF8C),
    Color(0xFFB839FF),
  ];

  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();

  late final AnimationController _saveController;
  late final Animation<double> _saveScale;

  File? _pickedImage;
  List<Circle> _circles = [];
  List<Profile> _people = [];
  final Set<String> _selectedCircleIds = {};
  final Set<String> _taggedPeople = {};

  bool _isLoadingCircles = true;
  bool _isLoadingPeople = false;
  bool _isSaving = false;
  bool _isLocating = false;
  bool _isPublic = false;
  String? _errorMessage;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _saveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _saveScale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _saveController, curve: Curves.easeOutCubic),
    );
    _scrollController.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollController.offset);
    });
    if (widget.initialCircleId != null) {
      _selectedCircleIds.add(widget.initialCircleId!);
    }
    _loadCircles();
    _captureLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    _scrollController.dispose();
    _saveController.dispose();
    super.dispose();
  }

  Future<void> _loadCircles() async {
    try {
      final circles = await CirclesRepository.fetchMyCircles();
      if (!mounted) return;
      setState(() {
        _circles = circles;
        if (_selectedCircleIds.isEmpty && circles.isNotEmpty) {
          _selectedCircleIds.add(circles.first.id);
        }
        _isLoadingCircles = false;
      });
      await _loadPeople();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCircles = false);
    }
  }

  Future<void> _loadPeople() async {
    if (_isPublic || _selectedCircleIds.isEmpty) {
      if (mounted) {
        setState(() {
          _people = [];
          _isLoadingPeople = false;
          _taggedPeople.clear();
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoadingPeople = true);
    try {
      final people = await CirclesRepository.fetchMembersForCircles(
        _selectedCircleIds.toList(),
      );
      if (!mounted) return;
      final validIds = people.map((p) => p.id).toSet();
      setState(() {
        _people = people;
        _taggedPeople.removeWhere((id) => !validIds.contains(id));
        _isLoadingPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _people = [];
        _isLoadingPeople = false;
      });
    }
  }

  Future<void> _captureLocation() async {
    if (mounted) setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final places = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted || places.isEmpty) return;
      final place = places.first;
      final parts = <String>[
        if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
        if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
        if ((place.administrativeArea ?? '').trim().isNotEmpty)
          place.administrativeArea!.trim(),
      ];
      if (parts.isNotEmpty && _locationController.text.trim().isEmpty) {
        _locationController.text = parts.join(', ');
      }
    } catch (_) {
      // Location is optional. Leave the field blank on failure or denial.
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _pickedImage = File(picked.path);
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = "Couldn't access that — try again.");
    }
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    if (_pickedImage == null) {
      setState(() => _errorMessage = 'Add a photo before saving.');
      return;
    }
    if (!_isPublic && _selectedCircleIds.isEmpty) {
      setState(() => _errorMessage = 'Choose at least one circle to share this with.');
      return;
    }

    await _saveController.forward();
    await _saveController.reverse();
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final captionText = _captionController.text.trim();
      final caption = [title, captionText]
          .where((text) => text.isNotEmpty)
          .join(' — ');

      await MemoriesRepository.addMemory(
        file: _pickedImage!,
        caption: caption.isEmpty ? null : caption,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        isPublic: _isPublic,
        circleIds: _isPublic ? const [] : _selectedCircleIds.toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = "Couldn't save this memory — try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.1,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding + 70),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MediaSection(
                    pickedImage: _pickedImage,
                    onPickCamera: () => _pickImage(ImageSource.camera),
                    onPickGallery: () => _pickImage(ImageSource.gallery),
                    onRemove: () => setState(() => _pickedImage = null),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(label: 'Memory Title'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SproutTextField(
                    controller: _titleController,
                    hint: 'Give this memory a name',
                    maxLines: 1,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(label: 'Caption'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SproutTextField(
                    controller: _captionController,
                    hint: 'What happened?',
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LocationField(
                    controller: _locationController,
                    isLocating: _isLocating,
                    onLocate: _captureLocation,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel(label: 'Share with'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PrivacySelector(
                    isPublic: _isPublic,
                    onChanged: (value) async {
                      setState(() {
                        _isPublic = value;
                        if (value) _selectedCircleIds.clear();
                      });
                      await _loadPeople();
                    },
                  ),
                ),
              ),
              if (!_isPublic) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_isLoadingCircles)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  )
                else if (_circles.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "You don't have any circles yet — create one first.",
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _CircleSelector(
                        circles: _circles,
                        selectedIds: _selectedCircleIds,
                        colors: _circleColors,
                        onToggle: (id) async {
                          setState(() {
                            if (_selectedCircleIds.contains(id)) {
                              _selectedCircleIds.remove(id);
                            } else {
                              _selectedCircleIds.add(id);
                            }
                          });
                          await _loadPeople();
                        },
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PeopleTagSection(
                      people: _people,
                      loading: _isLoadingPeople,
                      taggedIds: _taggedPeople,
                      onToggle: (id) => setState(() {
                        if (_taggedPeople.contains(id)) {
                          _taggedPeople.remove(id);
                        } else {
                          _taggedPeople.add(id);
                        }
                      }),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPadding + 115),
              ),
            ],
          ),
          _TopBar(topPadding: topPadding, scrollOffset: _scrollOffset),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    color: AppTheme.backgroundDark,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                _SaveMemoryBar(
                  isSaving: _isSaving,
                  scaleAnimation: _saveScale,
                  onSave: _handleSave,
                  bottomPadding: bottomPadding,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double topPadding;
  final double scrollOffset;

  const _TopBar({required this.topPadding, required this.scrollOffset});

  @override
  Widget build(BuildContext context) {
    final opacity = (scrollOffset / 50).clamp(0.0, 1.0);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: topPadding + 58,
        padding: EdgeInsets.only(top: topPadding, left: 16, right: 20),
        decoration: BoxDecoration(
          color: Color.lerp(Colors.transparent, const Color(0xFF0B1710), opacity),
          border: opacity > 0.5
              ? const Border(bottom: BorderSide(color: AppTheme.outline, width: 0.5))
              : null,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Create Memory',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final File? pickedImage;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  const _MediaSection({
    required this.pickedImage,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.file(
              pickedImage!,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(160),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withAlpha(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreen.withAlpha(80)),
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add Photo or Video',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Capture the moment that matters',
            style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MediaButton(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: onPickCamera)),
              const SizedBox(width: 10),
              Expanded(child: _MediaButton(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: onPickGallery)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF15351F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primaryGreen.withAlpha(25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 7),
            Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted,
          letterSpacing: 0.3,
        ),
      );
}

class _SproutTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputAction textInputAction;

  const _SproutTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textPrimary),
      cursorColor: AppTheme.primaryGreen,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textDisabled),
        filled: true,
        fillColor: const Color(0xFF0D2116),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withAlpha(28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withAlpha(28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1),
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLocating;
  final VoidCallback onLocate;

  const _LocationField({required this.controller, required this.isLocating, required this.onLocate});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textPrimary),
      cursorColor: AppTheme.primaryGreen,
      decoration: InputDecoration(
        hintText: isLocating ? 'Finding your location…' : 'Add location',
        hintStyle: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textDisabled),
        prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primaryGreen),
        suffixIcon: isLocating
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
              )
            : IconButton(
                onPressed: onLocate,
                icon: const Icon(Icons.my_location_rounded, size: 18, color: AppTheme.primaryGreen),
              ),
        filled: true,
        fillColor: const Color(0xFF0D2116),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withAlpha(28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withAlpha(28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1),
        ),
      ),
    );
  }
}

class _PrivacySelector extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const _PrivacySelector({required this.isPublic, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Public memory', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Anyone can discover it', style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
        Switch.adaptive(
          value: isPublic,
          onChanged: onChanged,
          activeColor: AppTheme.primaryGreen,
          activeTrackColor: AppTheme.primaryGreen.withAlpha(80),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: AppTheme.textDisabled,
        ),
      ],
    );
  }
}

class _CircleSelector extends StatelessWidget {
  final List<Circle> circles;
  final Set<String> selectedIds;
  final List<Color> colors;
  final Future<void> Function(String id) onToggle;

  const _CircleSelector({required this.circles, required this.selectedIds, required this.colors, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose one or more circles', style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < circles.length; i++)
              GestureDetector(
                onTap: () => onToggle(circles[i].id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: selectedIds.contains(circles[i].id) ? colors[i % colors.length].withAlpha(220) : const Color(0xFF0D2116),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selectedIds.contains(circles[i].id) ? colors[i % colors.length] : AppTheme.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedIds.contains(circles[i].id)) const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                      if (selectedIds.contains(circles[i].id)) const SizedBox(width: 5),
                      Text(circles[i].name, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: selectedIds.contains(circles[i].id) ? Colors.black : AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PeopleTagSection extends StatelessWidget {
  final List<Profile> people;
  final bool loading;
  final Set<String> taggedIds;
  final ValueChanged<String> onToggle;

  const _PeopleTagSection({required this.people, required this.loading, required this.taggedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Tag People'),
        const SizedBox(height: 12),
        if (loading)
          const SizedBox(height: 54, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)))
        else if (people.isEmpty)
          Text('No User in Circle', style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textMuted))
        else
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final person in people)
                GestureDetector(
                  onTap: () => onToggle(person.id),
                  child: SizedBox(
                    width: 62,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.surfaceVariantDark,
                              backgroundImage: person.avatarUrl?.isNotEmpty == true ? NetworkImage(person.avatarUrl!) : null,
                              child: person.avatarUrl?.isNotEmpty == true ? null : const Icon(Icons.person_outline, color: AppTheme.textDisabled),
                            ),
                            if (taggedIds.contains(person.id))
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded, size: 12, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          person.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: taggedIds.contains(person.id) ? AppTheme.primaryGreen : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SaveMemoryBar extends StatelessWidget {
  final bool isSaving;
  final Animation<double> scaleAnimation;
  final VoidCallback onSave;
  final double bottomPadding;

  const _SaveMemoryBar({required this.isSaving, required this.scaleAnimation, required this.onSave, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.backgroundDark.withAlpha(0), AppTheme.backgroundDark.withAlpha(245)],
        ),
      ),
      child: AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) => Transform.scale(scale: scaleAnimation.value, child: child),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppTheme.primaryGreen.withAlpha(130),
              elevation: 10,
              shadowColor: AppTheme.primaryGreen.withAlpha(100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: isSaving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.save_rounded, size: 17),
                    const SizedBox(width: 8),
                    Text('Save Memory', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800)),
                  ]),
          ),
        ),
      ),
    );
  }
}
