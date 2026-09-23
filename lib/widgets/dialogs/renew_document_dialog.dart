import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/expiry_item.dart';
import '../../services/collection_service.dart';
import '../../services/document_scanner_service.dart';

/// What the user confirmed in [showRenewDocumentDialog].
class RenewDocumentResult {
  /// The updated expiry date the document should be tracked until.
  final DateTime newExpiry;

  final double? fee;
  final String? renewedBy;
  final String? note;

  /// Newly picked replacement file, when the user chose to re-upload.
  final PlatformFile? replacementFile;

  const RenewDocumentResult({
    required this.newExpiry,
    this.fee,
    this.renewedBy,
    this.note,
    this.replacementFile,
  });
}

/// Asks the user to confirm a renewal by providing the new expiry date and,
/// optionally, a re-uploaded document file.
///
/// Renewing never deletes the document: the caller applies the result with
/// [DocumentScannerService.markAsRenewed] (which renews in place) and, when a
/// replacement file is given, [DocumentScannerService.replaceFile].
Future<RenewDocumentResult?> showRenewDocumentDialog(
  BuildContext context,
  ExpiryItem item,
) {
  final defaultExpiry = DateTime(
    item.expiresAt.year + 1,
    item.expiresAt.month,
    item.expiresAt.day,
  );

  return showDialog<RenewDocumentResult>(
    context: context,
    builder: (ctx) => _RenewDialog(item: item, defaultExpiry: defaultExpiry),
  );
}

class _RenewDialog extends StatefulWidget {
  final ExpiryItem item;
  final DateTime defaultExpiry;

  const _RenewDialog({required this.item, required this.defaultExpiry});

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog> {
  late DateTime _newExpiry = widget.defaultExpiry;
  PlatformFile? _replacementFile;
  bool _pickingFile = false;

  late final TextEditingController _feeController = TextEditingController(
    text: widget.item.renewalFee != null
        ? widget.item.renewalFee!.toStringAsFixed(0)
        : '',
  );
  late final TextEditingController _byController =
      TextEditingController(text: widget.item.assignedTo ?? '');
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _feeController.dispose();
    _byController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickReplacementFile() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg', 'txt',
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _replacementFile = result.files.first);
      }
    } catch (_) {
      // Picker unavailable / cancelled — keep the old file.
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newExpiry,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _newExpiry = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasOldFile = item.fileName != null && item.fileName!.isNotEmpty;

    return AlertDialog(
      title: Text('Renew ${item.displayName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current expiry: ${ExpiryItem.formatDate(item.expiresAt)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // New expiry date picker.
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'New expiry date *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                  isDense: true,
                ),
                child: Text(ExpiryItem.formatDate(_newExpiry)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Renewal fee / cost (${DocumentCollectionService.instance.activeCurrency})',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _byController,
              decoration: const InputDecoration(
                labelText: 'Renewed by (Person / Dept)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Re-upload option: keep the existing file or replace it.
            if (hasOldFile)
              Text(
                'Attached file: ${item.fileName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickingFile ? null : _pickReplacementFile,
              icon: _pickingFile
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(
                _replacementFile != null
                    ? 'Replace with: ${_replacementFile!.name}'
                    : hasOldFile
                        ? 'Re-upload document file'
                        : 'Attach document file',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_replacementFile != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _replacementFile = null),
                  child: const Text('Keep current file'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            Navigator.pop(
              context,
              RenewDocumentResult(
                newExpiry: _newExpiry,
                fee: double.tryParse(_feeController.text.trim()),
                renewedBy: _byController.text.trim(),
                note: _noteController.text.trim(),
                replacementFile: _replacementFile,
              ),
            );
          },
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Confirm Renewal'),
        ),
      ],
    );
  }
}

/// Copy a freshly picked replacement file into the app's documents directory
/// for [item], mirroring the upload flow in DocumentScanScreen. Returns the
/// stored path, or null when the pick has no accessible file.
Future<String?> saveRenewalReplacementFile(
  ExpiryItem item,
  PlatformFile file,
) async {
  final sourcePath = file.path;
  if (sourcePath == null || !File(sourcePath).existsSync()) return null;

  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDocDir.path}/wazy/documents/${item.id}');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    final targetPath = '${targetDir.path}/${file.name}';
    final saved = await File(sourcePath).copy(targetPath);
    return saved.path;
  } catch (_) {
    return sourcePath;
  }
}
