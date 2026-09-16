import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class WazyApp extends StatelessWidget {
  const WazyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wazy',
      debugShowCheckedModeBanner: false,
      theme: WazyTheme.light(),
      darkTheme: WazyTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
