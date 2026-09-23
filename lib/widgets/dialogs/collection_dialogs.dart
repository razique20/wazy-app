import 'package:flutter/material.dart';

import '../../models/document_collection.dart';
import '../../models/gcc_country.dart';

/// Result holder for collection creation.
class CollectionDialogData {
  final String name;
  final String countryCode;

  const CollectionDialogData({
    required this.name,
    this.countryCode = 'AE',
  });
}

/// Show a dialog to create a new company collection. Returns the chosen
/// name and country code, or null if cancelled.
Future<CollectionDialogData?> showCreateCollectionDialog(BuildContext context) {
  return showDialog<CollectionDialogData>(
    context: context,
    builder: (ctx) => const _CreateCollectionDialog(),
  );
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() => _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  GccCountry _selectedCountry = GccCountry.uae;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(
        context,
        CollectionDialogData(
          name: _controller.text.trim(),
          countryCode: _selectedCountry.code,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New collection'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use collections to keep business documents separate — '
                'one per company. Select the GCC country where the company is registered.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Collection name',
                  hintText: 'e.g. Al Mansoori Trading LLC',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter a name' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GccCountry>(
                value: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'GCC Country',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                items: GccCountry.values.map((country) {
                  return DropdownMenuItem<GccCountry>(
                    value: country,
                    child: Text('${country.flagEmoji} ${country.displayName} (${country.currency})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCountry = val);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
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

