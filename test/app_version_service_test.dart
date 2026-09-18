import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/services/app_version_service.dart';

void main() {
  group('AppVersionService Unit Tests', () {
    test('compareVersions accurately compares semantic version strings', () {
      expect(AppVersionService.compareVersions('1.0.0', '1.0.0'), equals(0));
      expect(AppVersionService.compareVersions('1.0.0', '1.0.1'), equals(-1));
      expect(AppVersionService.compareVersions('1.1.0', '1.0.5'), equals(1));
      expect(AppVersionService.compareVersions('2.0.0', '1.9.9'), equals(1));
      expect(AppVersionService.compareVersions('1.0.0+1', '1.0.0+2'), equals(0));
      expect(AppVersionService.compareVersions('1.2.3-beta', '1.2.3'), equals(0));
      expect(AppVersionService.compareVersions('1.2.0', '1.10.0'), equals(-1));
    });

    test('VersionCheckResult correctly determines shouldPromptUpdate', () {
      const upToDate = VersionCheckResult(
        status: VersionCheckStatus.upToDate,
        currentVersion: '1.0.0',
        latestVersion: '1.0.0',
        minRequiredVersion: '1.0.0',
        isForceUpdate: false,
      );
      expect(upToDate.shouldPromptUpdate, isFalse);

      const optional = VersionCheckResult(
        status: VersionCheckStatus.optionalUpdate,
        currentVersion: '1.0.0',
        latestVersion: '1.1.0',
        minRequiredVersion: '1.0.0',
        isForceUpdate: false,
      );
      expect(optional.shouldPromptUpdate, isTrue);

      const forced = VersionCheckResult(
        status: VersionCheckStatus.forceUpdate,
        currentVersion: '1.0.0',
        latestVersion: '1.2.0',
        minRequiredVersion: '1.1.0',
        isForceUpdate: true,
      );
      expect(forced.shouldPromptUpdate, isTrue);
    });
  });
}
