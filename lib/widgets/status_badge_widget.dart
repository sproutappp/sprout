import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MemoryPrivacy { private, circle, public }

class PrivacyBadgeWidget extends StatelessWidget {
  final MemoryPrivacy privacy;

  const PrivacyBadgeWidget({super.key, required this.privacy});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    Color color;

    switch (privacy) {
      case MemoryPrivacy.private:
        icon = Icons.lock_rounded;
        label = 'Only me';
        color = AppTheme.textMuted;
        break;
      case MemoryPrivacy.circle:
        icon = Icons.group_rounded;
        label = 'Circle';
        color = AppTheme.cyanAccent;
        break;
      case MemoryPrivacy.public:
        icon = Icons.public_rounded;
        label = 'Public';
        color = AppTheme.primaryGreen;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class CircleTagWidget extends StatelessWidget {
  final String name;
  final Color? color;

  const CircleTagWidget({super.key, required this.name, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.cyanAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withAlpha(64), width: 0.5),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}
