import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './app_navigation.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    // V3 Liquid Glass requires extendBody: true so content flows under the nav bar
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0A0F0D),
      body: navigationShell,
      bottomNavigationBar: AppNavigation(navigationShell: navigationShell),
    );
  }
}
