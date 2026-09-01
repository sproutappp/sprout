import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../services/profiles_repository.dart';

class HomeGreetingWidget extends StatefulWidget {
  const HomeGreetingWidget({super.key});

  @override
  State<HomeGreetingWidget> createState() => _HomeGreetingWidgetState();
}

class _HomeGreetingWidgetState extends State<HomeGreetingWidget> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final profile = await ProfilesRepository.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        final full = profile?.fullName;
        _name = (full != null && full.trim().isNotEmpty)
            ? full.trim().split(' ').first
            : null;
      });
    } catch (_) {
      // Greeting degrades gracefully to no name — not worth surfacing
      // an error for a cosmetic header.
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = _name != null ? ', $_name' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_getGreeting()}$greetingName ✦',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
