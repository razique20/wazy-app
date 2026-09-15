import 'package:flutter/material.dart';

import '../../models/document_collection.dart';

/// Bottom sheet / dialog helpers for managing the user's document
/// collections. Every user has a built-in Personal collection plus any
/// number of company collections.

/// Show a dialog to create a new company collection. Returns the chosen
/// name, or null if cancelled.
Future<String?> showCreateCollectionDialog(BuildContext context) {
  return _nameDialog(
    context,
    title: 'New collection',
    hint: 'e.g. Al Mansoori Trading LLC',
    actionLabel: 'Create',
    info: 'Use collections to keep business documents separate — '
        'one per company. Personal documents stay in Personal.',
  );
}

/// Show a dialog to rename a company collection. Returns the new name, or
/// null if cancelled. The personal collection cannot be renamed.
Future<String?> showRenameCollectionDialog(
  BuildContext context,
  DocumentCollection collection,
) {
  if (collection.isPersonal) return Future.value(null);
  return _nameDialog(
    context,
    title: 'Rename collection',
    hint: collection.name,
    actionLabel: 'Rename',
    initialText: collection.name,
  );
}

/// Show a confirm dialog to delete a company collection. Returns true when
/// the user confirmed. The personal collection cannot be deleted.
Future<bool> showDeleteCollectionDialog(
  BuildContext context,
  DocumentCollection collection,
) async {
  if (collection.isPersonal) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.delete_forever_rounded,
          color: Theme.of(ctx).colorScheme.error),
      title: const Text('Delete collection?'),
      content: Text(
        '"${collection.name}" and all documents inside it will be '
        'permanently removed. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// State holder for [_NameDialog] so the result survives the pop animation
/// without keeping a mutable closure variable.
class _NameDialogResult {
  String? value;
}

Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String actionLabel,
  String? initialText,
  String? info,
}) {
  final result = _NameDialogResult();

  return showDialog<String>(
    context: context,
    builder: (ctx) => _NameDialog(
      title: title,
      hint: hint,
      actionLabel: actionLabel,
      initialText: initialText,
      info: info,
      onDone: (value) {
        result.value = value;
        Navigator.pop(ctx, value);
      },
    ),
  ).then((popValue) => popValue ?? result.value);
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onDone,
    this.initialText,
    this.info,
  });

  final String title;
  final String hint;
  final String actionLabel;
  final String? initialText;
  final String? info;
  final ValueChanged<String?> onDone;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // The controller is disposed by the dialog's own State, i.e. only after
    // the route (including the exit animation) has fully left the tree —
    // never while the TextField is still mounted.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.info != null) ...[
              Text(
                widget.info!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Collection name',
                hintText: widget.hint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Enter a name' : null,
              onFieldSubmitted: (_) {
                if (_formKey.currentState!.validate()) {
                  widget.onDone(_controller.text.trim());
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onDone(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onDone(_controller.text.trim());
            }
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
