import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's theme preference (system / light / dark) and exposes
/// it as a [ChangeNotifier] so the root [MaterialApp] can react immediately.
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  factory ThemeService() => instance;

  static const String _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  /// The currently active theme mode.
  ThemeMode get mode => _mode;

  /// Load the persisted preference from disk. Safe to call multiple times —
  /// the first call wins and subsequent calls are no-ops.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    switch (stored) {
      case 'light':
        _mode = ThemeMode.light;
      case 'dark':
        _mode = ThemeMode.dark;
      default:
        _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Change the theme and persist the choice.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Convenience: cycle System → Light → Dark → System.
  Future<void> toggle() async {
    switch (_mode) {
      case ThemeMode.system:
        await setMode(ThemeMode.light);
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setMode(ThemeMode.system);
    }
  }
}
