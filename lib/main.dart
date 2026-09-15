import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/collection_service.dart';
import 'services/document_scanner_service.dart';
import 'services/finance_service.dart';
import 'services/supabase_service.dart';
import 'services/urgency_engine.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Supabase must be initialised once, before any service that uses it.
  // Credentials come from --dart-define build-time env vars (see .env.example
  // and SupabaseService). Without them the app runs in local-only mode.
  await SupabaseService.initialize();

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
    await Future.wait([
      DocumentCollectionService.instance.init(),
      DocumentScannerService.instance.init(),
      FinanceService.instance.init(),
    ]);
  }
}
