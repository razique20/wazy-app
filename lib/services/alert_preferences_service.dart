import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide alert preferences, persisted in SharedPreferences.
///
/// Gates every surface an alert can appear on:
/// * **Bill spike alerts** — the Bill Spike card on MoneyScreen.
/// * **Budget alerts** — the in-app snackbar + stream from
///   [BudgetAlertService], the OS-level budget notification, and the Money
///   tab badge in the router shell.
/// * **Document expiry reminders** — OS-scheduled renewal notifications
///   (the 90/60/30/7 ladder). The Profile screen's existing
///   `notificationsEnabled` pref feeds this; both must be on for reminders.
///
/// Defaults are all-on; toggles take effect immediately (in-memory) and
/// survive restarts.
class AlertPreferencesService {
  AlertPreferencesService._();

  static final AlertPreferencesService instance = AlertPreferencesService._();

  static const String _billSpikesKey = 'alerts.billSpikesEnabled';
  static const String _budgetKey = 'alerts.budgetAlertsEnabled';

  bool _billSpikesEnabled = true;
  bool _budgetAlertsEnabled = true;

  /// Bill spike alerts (anomalous price jumps on recent bills).
  bool get billSpikesEnabled => _billSpikesEnabled;

  /// Budget threshold alerts (80% / 100% of a category budget).
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;

  /// Load persisted values. Call once at startup; safe to call again.
  /// Falls back to all-on if storage is unavailable.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _billSpikesEnabled = prefs.getBool(_billSpikesKey) ?? true;
      _budgetAlertsEnabled = prefs.getBool(_budgetKey) ?? true;
    } catch (_) {
      // Keep defaults if storage fails (e.g. plugin not ready in tests).
    }
  }

  Future<void> setBillSpikesEnabled(bool value) async {
    _billSpikesEnabled = value;
    await _persist(_billSpikesKey, value);
  }

  Future<void> setBudgetAlertsEnabled(bool value) async {
    _budgetAlertsEnabled = value;
    await _persist(_budgetKey, value);
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // In-memory value already applied; persistence is best-effort.
    }
  }

  /// Reset to defaults. Used by tests.
  @visibleForTesting
  void reset() {
    _billSpikesEnabled = true;
    _budgetAlertsEnabled = true;
  }
}
