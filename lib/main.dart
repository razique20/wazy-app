import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/budget_alert_service.dart';
import 'services/gemini_api_service.dart';
import 'services/collection_service.dart';
import 'services/custom_document_type_service.dart';
import 'services/document_scanner_service.dart';
import 'services/finance_service.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';
import 'services/urgency_engine.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load the user's theme preference before the first frame.
  await ThemeService.instance.init();

  // Supabase must be initialised once, before any service that uses it.
  // Credentials come from AppCredentials (lib/config/app_credentials.dart).
  // Without them the app runs in local-only mode.
  await SupabaseService.initialize();

  // Budget alerts listen to finance data changes for the whole app lifetime
  // (OS notifications + Money-tab badge + snackbars).
  await BudgetAlertService.instance.init();
  unawaited(GeminiApiService.instance.load()); // optional LLM key for AI features

  // Prewarm services. Auth session is restored from secure storage by
  // supabase_flutter during Supabase.initialize, so by this point
  // AuthService.isSignedIn is already correct on cold start.
  await _prewarmServices();

  runApp(const WazyApp());
}

/// Initialise the services that don't depend on auth first, then the
/// Supabase-backed ones (only meaningful when a session exists).
Future<void> _prewarmServices() async {
  await Future.wait([
    UrgencyEngine().init(),
    NotificationService().init(),
  ]);

  if (AuthService.instance.isSignedIn) {
    // Custom types must load before documents: rows are decoded into
    // ExpiryItems during init and need the registry to resolve doc_type keys.
    await CustomDocumentTypeService.instance.init();
    await Future.wait([
      DocumentCollectionService.instance.init(),
      DocumentScannerService.instance.init(),
      FinanceService.instance.init(),
    ]);

    // Initial evaluation once finance data is loaded (catches thresholds
    // crossed while the app was closed — e.g. an auto-logged rent payment
    // pushing a budget past 100%).
    unawaited(BudgetAlertService.instance.evaluateNow());

    // Bring the OS-scheduled reminders back in sync with the loaded
    // documents (clears stale entries, schedules the 90/60/30/7 ladder).
    try {
      final items = await DocumentScannerService.instance.getAllItems();
      await NotificationService.instance.resyncAll(
        items
            .map((i) => (id: i.id, name: i.displayName, expiresAt: i.expiresAt))
            .toList(),
      );
    } catch (_) {
      // Best-effort: never block startup over reminders.
    }
  }
}
