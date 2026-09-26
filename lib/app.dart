import 'package:flutter/material.dart';

import 'router.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

class FinavigApp extends StatefulWidget {
  const FinavigApp({super.key});

  @override
  State<FinavigApp> createState() => _FinavigAppState();
}

class _FinavigAppState extends State<FinavigApp> {
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
      title: 'Finavig',
      debugShowCheckedModeBanner: false,
      theme: FinavigTheme.light(),
      darkTheme: FinavigTheme.dark(),
      themeMode: ThemeService.instance.mode,
      routerConfig: router,
    );
  }
}
