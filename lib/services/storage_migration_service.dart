import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time migration of user documents from the legacy Wazy storage folder
/// (`<app docs>/wazy/documents`) to the Finavig folder
/// (`<app docs>/finavig/documents`).
///
/// Runs at most once per install — the [storageMigrationDoneKey] flag in
/// SharedPreferences marks completion so startup never pays the cost again.
/// Failures are swallowed: the caller treats migration as best-effort and the
/// document screens recreate their target directories on demand anyway.
class StorageMigrationService {
  StorageMigrationService._();

  static const String legacyFolderName = 'wazy';
  static const String newFolderName = 'finavig';

  /// SharedPreferences flag set after the first successful (or no-op) run.
  static const String storageMigrationDoneKey = 'finavig.storage.migrated.v1';

  /// Moves `<docs>/wazy/documents` → `<docs>/finavig/documents` if needed.
  static Future<void> migrate() async {
    try {
      // Run at most once per install; skip immediately afterwards.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(storageMigrationDoneKey) ?? false) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final legacyRoot = Directory('${docsDir.path}/$legacyFolderName');
      if (!legacyRoot.existsSync()) return; // Fresh install — nothing to do.

      final legacyDocs = Directory('${legacyRoot.path}/documents');
      final newRoot = Directory('${docsDir.path}/$newFolderName');
      final newDocs = Directory('${newRoot.path}/documents');

      if (!newRoot.existsSync()) {
        // Fast path: the whole legacy tree can be moved atomically.
        legacyRoot.renameSync(newRoot.path);
        return;
      }

      // Finavig folder already exists (e.g. the app ran before the flag was
      // set): merge per-document folders without overwriting existing files.
      if (legacyDocs.existsSync()) {
        for (final entity in legacyDocs.listSync()) {
          if (entity is! Directory) continue;
          final target = Directory('${newDocs.path}/${entity.uri.pathSegments.reversed.skip(1).first}');
          if (target.existsSync()) continue;
          entity.renameSync(target.path);
        }
      }
    } catch (_) {
      // Best-effort: never block startup over storage migration.
    }

    // Mark done even on failure so a persistent problem can't slow every
    // cold start; the screens recreate target directories on demand anyway.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageMigrationDoneKey, true);
    } catch (_) {
      // Ignore — worst case the (idempotent) migration runs once more.
    }
  }
}
