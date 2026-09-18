import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/document_type.dart';
import '../../models/expiry_item.dart';
import '../../services/companion_document_factory.dart';
import '../../services/companion_suggestion_service.dart';
import '../../services/document_scanner_service.dart';

/// Bottom sheet shown after a document is added, suggesting related document
/// types from the same UAE companion pool that the user does not track yet.
///
/// Returns the list of types the user chose to add (empty when dismissed).
class CompanionSuggestionSheet extends StatefulWidget {
  /// The type of the document the user just added.
  final DocumentType addedType;

  /// Name shown in the header, e.g. the new document's title.
  final String addedName;

  /// Doc-type keys of the user's currently tracked documents.
  final Set<String> trackedTypeKeys;

  const CompanionSuggestionSheet({
    super.key,
    required this.addedType,
    required this.addedName,
    required this.trackedTypeKeys,
  });

  /// Opens the sheet and returns the picked types (empty list on dismiss).
  static Future<List<DocumentType>> show(
    BuildContext context, {
    required DocumentType addedType,
    required String addedName,
    required Set<String> trackedTypeKeys,
  }) async {
    final picked = await showModalBottomSheet<List<DocumentType>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CompanionSuggestionSheet(
        addedType: addedType,
        addedName: addedName,
        trackedTypeKeys: trackedTypeKeys,
      ),
    );
    return picked ?? const [];
  }

  /// Evaluates whether [newItem] has companion document suggestions available,
  /// and if so, shows the [CompanionSuggestionSheet] bottom modal on the root navigator.
  static Future<void> maybeSuggestCompanions(
    BuildContext context,
    ExpiryItem newItem,
  ) async {
    if (newItem.docType.builtinEnum == null) return;
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      final tracked = await DocumentScannerService.instance.getAllItems();
      final suggestions = CompanionSuggestionService.instance.suggestionsFor(
        newItem.docType.builtinEnum!,
        tracked.map((i) => i.docType.key).toSet(),
      );
      if (suggestions.isEmpty) return;

      final picked = await show(
        navigator.context,
        addedType: newItem.docType.builtinEnum!,
        addedName: newItem.displayName,
        trackedTypeKeys: tracked.map((i) => i.docType.key).toSet(),
      );
      if (picked.isEmpty) return;

      for (final type in picked) {
        await DocumentScannerService.instance.addItem(
          buildCompanionItem(
            type: type,
            collectionId: newItem.collectionId,
            anchoredToName: newItem.displayName,
          ),
        );
      }
      final messenger = ScaffoldMessenger.maybeOf(navigator.context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            '${picked.length} related document${picked.length == 1 ? '' : 's'} added ✓',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {}
  }

  @override
  State<CompanionSuggestionSheet> createState() =>
      _CompanionSuggestionSheetState();
}

class _CompanionSuggestionSheetState extends State<CompanionSuggestionSheet> {
  final Set<DocumentType> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = CompanionSuggestionService.instance.suggestionsFor(
      widget.addedType,
      widget.trackedTypeKeys,
    );

    // Nothing to suggest — do not show an empty sheet.
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final pools = suggestions.map((s) => s.poolName).toSet();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add related documents?',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Businesses tracking a ${_typeName(widget.addedType)} usually also track:',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final poolName in pools) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Text(
                        poolName.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    for (final s in suggestions.where(
                      (s) => s.poolName == poolName,
                    ))
                      _SuggestionTile(
                        suggestion: s,
                        selected: _selected.contains(s.type),
                        onToggle: () => setState(() {
                          if (!_selected.remove(s.type)) _selected.add(s.type);
                        }),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, const []),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      _selected.isEmpty
                          ? 'Add selected'
                          : 'Add ${_selected.length} document${_selected.length == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  String _typeName(DocumentType type) =>
      DocumentTypeRegistry.instance.byEnum(type).displayName.toLowerCase();
}

/// One tappable suggestion row with the type's icon/color, name and reason.
class _SuggestionTile extends StatelessWidget {
  final CompanionSuggestion suggestion;
  final bool selected;
  final VoidCallback onToggle;

  const _SuggestionTile({
    required this.suggestion,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = suggestion.meta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? meta.primaryColor : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? meta.primaryColor.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: meta.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, color: meta.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.displayName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? meta.primaryColor : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
