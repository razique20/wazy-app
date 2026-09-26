import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/finance.dart';
import '../../services/finance_service.dart';
import '../../screens/money_screen.dart';
import '../../theme/app_theme.dart';
import 'natural_language_money_add_dialog.dart';
import 'upgrade_dialog.dart';

/// Universal Quick Action sheet — the "+" speed dial menu on the main nav
/// shell. One tap from any tab reaches the core creation flows:
/// scan/add a document, log an expense or income (smart category matching
/// built into [TransactionFormSheet]), and the voice AI logger.
///
/// Actions reuse the exact flows the individual tabs use, so quotas and
/// entitlement gates (document limit, plan restrictions) stay enforced in
/// one place.
Future<void> showQuickActionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => const _QuickActionSheet(),
  );
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet();

  Future<void> _handleTap(
    BuildContext context,
    _QuickAction action,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    switch (action) {
      case _QuickAction.scanDocument:
        // Mirror HomeScreen._openScanner: free-plan document quota first,
        // then the full-screen scan flow above the shell.
        if (!context.mounted) return;
        if (!await enforceDocumentLimit(context)) return;
        if (!context.mounted) return;
        await context.push('/scan');
        break;
      case _QuickAction.logMoney:
        // Same form sheet the Money tab uses; the sheet returns the created
        // record and we persist it here so FinanceService notifies tabs.
        if (!context.mounted) return;
        final created = await showModalBottomSheet<FinanceTransaction>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const TransactionFormSheet(),
        );
        if (created != null) {
          await FinanceService.instance.addTransaction(created);
        }
        break;
      case _QuickAction.voiceAiLog:
        // "Talk to Finavig": type or speak natural language; the parser
        // auto-categorizes and returns the created record, if any.
        if (!context.mounted) return;
        final created = await NaturalLanguageMoneyAddDialog.show(context);
        if (created != null) {
          await FinanceService.instance.addTransaction(created);
        }
        break;
    }

    // All flows end by dismissing the quick menu (when it is still
    // open — e.g. the scan flow pushed a route above it, leaving the sheet
    // mounted underneath).
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? FinavigColors.slate : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle, matching the collection switcher sheet.
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      'Quick actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final action in _QuickAction.values)
                _QuickActionTile(
                  action: action,
                  isDark: isDark,
                  onTap: () => _handleTap(context, action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _QuickAction {
  scanDocument,
  logMoney,
  voiceAiLog,
}

extension _QuickActionX on _QuickAction {
  IconData get icon {
    switch (this) {
      case _QuickAction.scanDocument:
        return Icons.document_scanner_rounded;
      case _QuickAction.logMoney:
        return Icons.receipt_long_rounded;
      case _QuickAction.voiceAiLog:
        return Icons.mic_rounded;
    }
  }

  String get title {
    switch (this) {
      case _QuickAction.scanDocument:
        return 'Scan / Add Document';
      case _QuickAction.logMoney:
        return 'Log Expense or Income';
      case _QuickAction.voiceAiLog:
        return 'Voice AI Log';
    }
  }

  String get subtitle {
    switch (this) {
      case _QuickAction.scanDocument:
        return 'Open the camera or upload a file';
      case _QuickAction.logMoney:
        return 'Smart category matching included';
      case _QuickAction.voiceAiLog:
        return 'Talk to Finavig — it does the typing';
    }
  }

  Color get color {
    switch (this) {
      case _QuickAction.scanDocument:
        return FinavigColors.violet;
      case _QuickAction.logMoney:
        return FinavigColors.violetAccent;
      case _QuickAction.voiceAiLog:
        return FinavigColors.ink;
    }
  }
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.action,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = action.color;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
