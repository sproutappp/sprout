import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class SetHomePreviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String sourceExtension;

  const SetHomePreviewScreen({
    super.key,
    required this.imageBytes,
    required this.sourceExtension,
  });

  @override
  State<SetHomePreviewScreen> createState() => _SetHomePreviewScreenState();
}

class _SetHomePreviewScreenState extends State<SetHomePreviewScreen> {
  final CropController _cropController = CropController();
  bool _cropping = false;
  String? _error;

  void _setHomePreview() {
    if (_cropping) return;
    setState(() {
      _cropping = true;
      _error = null;
    });
    _cropController.crop();
  }

  Future<void> _finishWithCrop(Uint8List croppedBytes) async {
    try {
      final extension =
          widget.sourceExtension.toLowerCase() == 'png' ? 'png' : 'jpg';
      final file = File(
        '${Directory.systemTemp.path}/sprout_home_preview_${DateTime.now().microsecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(croppedBytes, flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted) {
        setState(() {
          _cropping = false;
          _error = "Couldn't set the Home Preview. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: Text(
          'Set Home Preview',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Choose how your photo will appear in Home → Discover.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: Crop(
                image: widget.imageBytes,
                controller: _cropController,
                aspectRatio: 16 / 9,
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                  size: 1,
                  aspectRatio: 16 / 9,
                ),
                interactive: true,
                fixCropRect: true,
                maskColor: Colors.black.withAlpha(150),
                baseColor: Colors.black,
                radius: 10,
                cornerDotBuilder: (size, edgeAlignment) =>
                    const SizedBox.shrink(),
                progressIndicator: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                onCropped: (result) {
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      _finishWithCrop(croppedImage);
                    case CropFailure(:final cause):
                      if (mounted) {
                        setState(() {
                          _cropping = false;
                          _error = 'Could not crop the image: $cause';
                        });
                      }
                  }
                },
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.error,
                  fontSize: 11,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _cropping ? null : _setHomePreview,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.primaryGreen.withAlpha(100),
                ),
                child: _cropping
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Set Home Preview',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
