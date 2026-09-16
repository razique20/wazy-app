import 'package:flutter/material.dart';

import 'router.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

class WazyApp extends StatefulWidget {
  const WazyApp({super.key});

  @override
  State<WazyApp> createState() => _WazyAppState();
}

class _WazyAppState extends State<WazyApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wazy',
      debugShowCheckedModeBanner: false,
      theme: WazyTheme.light(),
      darkTheme: WazyTheme.dark(),
      themeMode: ThemeService.instance.mode,
      routerConfig: router,
    );
  }
}
