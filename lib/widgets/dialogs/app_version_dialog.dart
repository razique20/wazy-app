import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_version_service.dart';

class AppVersionDialog extends StatelessWidget {
  final VersionCheckResult result;

  const AppVersionDialog({
    super.key,
    required this.result,
  });

  /// Displays the version update dialog if an update is available or required.
  /// Returns `true` if the user chose to update or skipped an optional update,
  /// or `false` if dismissed.
  static Future<bool> showIfNeeded(
    BuildContext context,
    VersionCheckResult result,
  ) async {
    if (!result.shouldPromptUpdate) return true;

    final isForce = result.status == VersionCheckStatus.forceUpdate;

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) => PopScope(
        canPop: !isForce,
        child: AppVersionDialog(result: result),
      ),
    );

    return res ?? !isForce;
  }

  Future<void> _launchUpdateUrl(BuildContext context) async {
    final urlStr = result.downloadUrl ?? 'https://github.com/razique20/wazy-app/releases';
    final uri = Uri.parse(urlStr);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlStr')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForce = result.status == VersionCheckStatus.forceUpdate;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isForce ? Colors.red.shade100 : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isForce ? Icons.system_update_rounded : Icons.rocket_launch_rounded,
              color: isForce ? Colors.red.shade900 : theme.colorScheme.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isForce ? 'Update Required' : 'Update Available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'v${result.latestVersion} is now ready',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isForce
                ? 'Your installed version (v${result.currentVersion}) is no longer supported. Please update to v${result.latestVersion} to continue using Wazy.'
                : 'A new version of Wazy (v${result.latestVersion}) is available. Your installed version is v${result.currentVersion}.',
            style: theme.textTheme.bodyMedium,
          ),
          if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s New:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.releaseNotes!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!isForce)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
        FilledButton.icon(
          onPressed: () => _launchUpdateUrl(context),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(isForce ? 'Update Now' : 'Update App'),
          style: FilledButton.styleFrom(
            backgroundColor: isForce ? Colors.red.shade700 : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
