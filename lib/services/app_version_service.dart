import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

enum VersionCheckStatus {
  upToDate,
  optionalUpdate,
  forceUpdate,
}

class VersionCheckResult {
  final VersionCheckStatus status;
  final String currentVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final bool isForceUpdate;
  final String? downloadUrl;
  final String? releaseNotes;

  const VersionCheckResult({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.isForceUpdate,
    this.downloadUrl,
    this.releaseNotes,
  });

  bool get shouldPromptUpdate =>
      status == VersionCheckStatus.optionalUpdate ||
      status == VersionCheckStatus.forceUpdate;
}

class AppVersionService {
  AppVersionService._();
  static final AppVersionService instance = AppVersionService._();

  /// Current app version built into this release.
  static const String currentAppVersion = '1.0.0';

  /// Performs a version check against Supabase `app_versions` table.
  /// Defaults gracefully to [VersionCheckStatus.upToDate] if network or Supabase is unavailable.
  Future<VersionCheckResult> checkAppVersion({String platform = 'all'}) async {
    final auth = AuthService.instance;
    if (!auth.isAvailable) {
      return const VersionCheckResult(
        status: VersionCheckStatus.upToDate,
        currentVersion: currentAppVersion,
        latestVersion: currentAppVersion,
        minRequiredVersion: currentAppVersion,
        isForceUpdate: false,
      );
    }

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_versions')
          .select()
          .or('platform.eq.$platform,platform.eq.all')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return const VersionCheckResult(
          status: VersionCheckStatus.upToDate,
          currentVersion: currentAppVersion,
          latestVersion: currentAppVersion,
          minRequiredVersion: currentAppVersion,
          isForceUpdate: false,
        );
      }

      final minRequired = (response['min_required_version'] as String?) ?? currentAppVersion;
      final latest = (response['latest_version'] as String?) ?? currentAppVersion;
      final isForce = (response['is_force_update'] as bool?) ?? false;
      final downloadUrl = response['download_url'] as String?;
      final notes = response['release_notes'] as String?;

      VersionCheckStatus status;

      if (compareVersions(currentAppVersion, minRequired) < 0) {
        status = VersionCheckStatus.forceUpdate;
      } else if (isForce && compareVersions(currentAppVersion, latest) < 0) {
        status = VersionCheckStatus.forceUpdate;
      } else if (compareVersions(currentAppVersion, latest) < 0) {
        status = VersionCheckStatus.optionalUpdate;
      } else {
        status = VersionCheckStatus.upToDate;
      }

      return VersionCheckResult(
        status: status,
        currentVersion: currentAppVersion,
        latestVersion: latest,
        minRequiredVersion: minRequired,
        isForceUpdate: isForce,
        downloadUrl: downloadUrl,
        releaseNotes: notes,
      );
    } catch (e) {
      debugPrint('AppVersionService: Failed to check app version — $e');
      return const VersionCheckResult(
        status: VersionCheckStatus.upToDate,
        currentVersion: currentAppVersion,
        latestVersion: currentAppVersion,
        minRequiredVersion: currentAppVersion,
        isForceUpdate: false,
      );
    }
  }

  /// Compares two semantic version strings (e.g. "1.0.0" vs "1.1.0").
  /// Returns -1 if v1 < v2, 1 if v1 > v2, and 0 if v1 == v2.
  static int compareVersions(String v1, String v2) {
    try {
      final cleanV1 = v1.split('+').first.split('-').first;
      final cleanV2 = v2.split('+').first.split('-').first;

      final parts1 = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

      for (int i = 0; i < maxLength; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;

        if (p1 < p2) return -1;
        if (p1 > p2) return 1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
