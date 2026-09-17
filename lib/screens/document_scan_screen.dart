import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/document_collection.dart';
import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../services/collection_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/document_scanner_service.dart';
import '../services/uae_document_ocr_service.dart';

enum UaeEmirate {
  dubai('Dubai'),
  abuDhabi('Abu Dhabi'),
  sharjah('Sharjah'),
  ajman('Ajman'),
  rak('Ras Al Khaimah'),
  fujairah('Fujairah'),
  uaq('Umm Al Quwain'),
  federal('Federal / UAE-Wide');

  final String displayName;
  const UaeEmirate(this.displayName);
}

final Map<UaeEmirate, List<String>> _emirateAuthorities = {
  UaeEmirate.dubai: [
    'Dubai DET / DED (Department of Economy & Tourism)',
    'RERA / Dubai Land Department (Ejari)',
    'GDRFA Dubai (General Directorate of Residency)',
    'RTA Dubai (Roads & Transport Authority)',
    'DHA (Dubai Health Authority)',
    'Dubai Municipality',
    'DIFC (Dubai International Financial Centre)',
    'DDA (Dubai Development Authority / Free Zones)',
    'Dubai Courts',
  ],
  UaeEmirate.abuDhabi: [
    'ADDED (Abu Dhabi Dept of Economic Development)',
    'TAMM / Municipality of Abu Dhabi',
    'ICP Abu Dhabi (Identity & Citizenship)',
    'Integrated Transport Centre (ITC / DoT)',
    'DOH (Department of Health Abu Dhabi)',
    'ADGM (Abu Dhabi Global Market)',
  ],
  UaeEmirate.sharjah: [
    'Sharjah SEDD (Economic Development Dept)',
    'Sharjah City Municipality',
    'Sharjah SRTA (Roads & Transport Authority)',
    'Sharjah Police',
  ],
  UaeEmirate.ajman: [
    'Ajman DED (Department of Economic Development)',
    'Ajman Municipality & Planning Department',
    'Ajman Transport Authority',
  ],
  UaeEmirate.rak: [
    'RAK DED (Department of Economic Development)',
    'RAK Municipality',
    'RAK Public Services / RTA',
  ],
  UaeEmirate.fujairah: [
    'Fujairah Municipality',
    'Fujairah Free Zone Authority',
  ],
  UaeEmirate.uaq: [
    'UAQ DED (Department of Economic Development)',
    'UAQ Municipality',
  ],
  UaeEmirate.federal: [
    'ICP (Federal Identity, Citizenship & Customs)',
    'MOHRE (Ministry of Human Resources & Emiratisation)',
    'Ministry of Economy UAE',
    'FTA (Federal Tax Authority - TRN/VAT)',
    'Central Bank of the UAE',
    'TDRA (Telecommunications & Digital Regulatory Authority)',
  ],
};

/// Full screen form to upload a document file and track its expiry date & renewal cost.
class DocumentScanScreen extends StatefulWidget {
  const DocumentScanScreen({super.key});

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _feeController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  DocumentTypeMeta _docType =
      DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence);
  UaeEmirate _selectedEmirate = UaeEmirate.dubai;
  late String _selectedAuthority;
  bool _isCustomAuthority = false;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 365));
  PlatformFile? _attachedFile;
  bool _isSaving = false;
  bool _isScanningOcr = false;
  UaeOcrResult? _ocrResult;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _feeController = TextEditingController();
    _selectedAuthority = _emirateAuthorities[UaeEmirate.dubai]!.first;
    _locationController = TextEditingController(text: _selectedAuthority);
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _feeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _runOcrScan(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg'].contains(ext);

    if (!isImage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR extraction is optimized for image documents (PNG, JPG). For PDFs, enter details manually.'),
        ),
      );
      return;
    }

    setState(() => _isScanningOcr = true);

    try {
      final res = await UaeDocumentOcrService.instance.processImageFile(filePath);

      if (!mounted) return;

      if (!res.hasAnyExtractedField) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No clear UAE document fields recognized. You can still enter details manually.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isScanningOcr = false;
          _ocrResult = null;
        });
        return;
      }

      setState(() {
        _ocrResult = res;
        _isScanningOcr = false;

        // Auto-fill extracted values into form fields
        if (res.title != null && res.title!.isNotEmpty) {
          _titleController.text = res.title!;
        }
        if (res.documentType != null) {
          _docType = res.documentType!;
        }
        if (res.expiryDate != null) {
          _expiresAt = res.expiryDate!;
        }
        if (res.emirate != null) {
          _selectedEmirate = res.emirate!;
          final list = _emirateAuthorities[res.emirate!] ?? [];
          if (res.authority != null && list.contains(res.authority)) {
            _selectedAuthority = res.authority!;
            _isCustomAuthority = false;
            _locationController.text = res.authority!;
          } else if (list.isNotEmpty) {
            _selectedAuthority = list.first;
            _isCustomAuthority = false;
            _locationController.text = list.first;
          }
        }

        // Add document number to description if found
        if (res.documentNumber != null && res.documentNumber!.isNotEmpty) {
          if (!_descriptionController.text.contains(res.documentNumber!)) {
            final prefix = _descriptionController.text.trim().isNotEmpty
                ? '${_descriptionController.text.trim()}\n'
                : '';
            _descriptionController.text = '${prefix}Doc No: ${res.documentNumber}';
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.bolt, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text('Form pre-filled from scan! Please review & confirm before saving.'),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanningOcr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR extraction error: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg', 'txt',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _attachedFile = file;
          _ocrResult = null;
          if (_titleController.text.trim().isEmpty) {
            final nameWithoutExt = file.name.contains('.')
                ? file.name.substring(0, file.name.lastIndexOf('.'))
                : file.name;
            final cleanName = nameWithoutExt.replaceAll(RegExp(r'[-_]'), ' ').trim();
            if (cleanName.isNotEmpty) {
              _titleController.text = cleanName;
            }
          }
        });

        // Trigger OCR automatically for image files
        if (file.path != null) {
          final ext = file.extension?.toLowerCase();
          if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
            _runOcrScan(file.path!);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  /// Bottom sheet to define a new custom document type on the fly.
  /// On save it registers the type and selects it for this document.
  Future<void> _addCustomType() async {
    final nameCtrl = TextEditingController();
    final authorityCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '365');

    final created = await showModalBottomSheet<DocumentTypeMeta>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New document type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Create your own category beyond the built-in UAE types.',
              style: TextStyle(color: Theme.of(sheetContext).hintColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Type name *',
                hintText: 'e.g. Trade Licence Renewal Receipt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Renewal authority (optional)',
                hintText: 'e.g. Dubai Municipality',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Renewal cycle (days)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    try {
                      final meta = await CustomDocumentTypeService.instance
                          .create(
                        name: name,
                        renewalAuthority: authorityCtrl.text.trim(),
                        typicalRenewalDays:
                            int.tryParse(daysCtrl.text.trim()) ?? 365,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, meta);
                    } on ArgumentError catch (e) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.message.toString().replaceFirst('Bad state: ', ''),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (_) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Could not save the document type'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (created != null && mounted) {
      setState(() => _docType = created);
    }
  }

  UrgencyLevel _determineUrgency(int days) {
    if (days <= 7) return UrgencyLevel.critical;
    if (days <= 30) return UrgencyLevel.high;
    if (days <= 60) return UrgencyLevel.medium;
    return UrgencyLevel.low;
  }

  int _determineReminderStatus(int days) {
    if (days <= 7) return 4;
    if (days <= 30) return 3;
    if (days <= 60) return 2;
    if (days <= 90) return 1;
    return 0;
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final daysOffset = _expiresAt.difference(now).inDays;
      final fee = double.tryParse(_feeController.text.trim());
      final finalLocation = _isCustomAuthority
          ? '${_locationController.text.trim()} (${_selectedEmirate.displayName})'
          : _selectedAuthority;

      final docId = const Uuid().v4();
      String? localSavedPath = _attachedFile?.path;
      if (_attachedFile?.path != null && File(_attachedFile!.path!).existsSync()) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final targetDir = Directory('${appDocDir.path}/wazy/documents/$docId');
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          final fileName = _attachedFile!.name;
          final targetPath = '${targetDir.path}/$fileName';
          final savedFile = await File(_attachedFile!.path!).copy(targetPath);
          localSavedPath = savedFile.path;
        } catch (_) {
          localSavedPath = _attachedFile?.path;
        }
      }

      final item = ExpiryItem(
        id: docId,
        collectionId: DocumentCollectionService.instance.activeCollectionId,
        displayName: _titleController.text.trim(),
        docType: _docType,
        expiryDate: DateFormat('dd MMM yyyy').format(_expiresAt),
        daysRemaining: daysOffset,
        isExpired: daysOffset < 0,
        isNotified: false,
        notifiedDays: null,
        description: _descriptionController.text.trim(),
        location: finalLocation,
        reminderStatus: _determineReminderStatus(daysOffset),
        urgency: _determineUrgency(daysOffset),
        assignedTo: null,
        documentDate: DateFormat('dd MMM yyyy').format(now),
        renewalFee: fee,
        renewalSteps: [
          'Gather required documentation',
          'Prepare renewal application',
          'Submit to relevant authority',
          'Pay renewal fees',
          'Receive renewed document',
        ],
        renewalAuthorities: [_selectedAuthority],
        renewalWarning: daysOffset <= 30 ? 'Expires soon — renew to avoid penalties' : null,
        expiresAt: _expiresAt,
        fileName: _attachedFile?.name,
        filePath: localSavedPath,
        fileSize: _attachedFile?.size,
      );

      await DocumentScannerService.instance.addItem(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.displayName} added to tracking'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysRemaining = _expiresAt.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload document'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload your document file and enter expiry details to start tracking.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // File Upload Attachment Box
              if (_attachedFile == null)
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to select & attach document file',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supports PDF, DOC, XLS, PNG, JPG (Auto-OCR for Images)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.insert_drive_file_outlined,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _attachedFile!.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(_attachedFile!.size / 1024).toStringAsFixed(0)} KB • ${_attachedFile!.extension?.toUpperCase() ?? "FILE"}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _attachedFile = null;
                              _ocrResult = null;
                            }),
                            tooltip: 'Remove file',
                          ),
                        ],
                      ),
                    ),
                    if (_attachedFile?.path != null &&
                        ['png', 'jpg', 'jpeg'].contains(_attachedFile!.extension?.toLowerCase())) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isScanningOcr
                              ? null
                              : () => _runOcrScan(_attachedFile!.path!),
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Re-scan Image with OCR'),
                        ),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 16),

              // Scanning indicator
              if (_isScanningOcr)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scanning document with ML Kit OCR...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Extracting expiry date, license no, title & jurisdiction...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // OCR Summary Banner
              if (_ocrResult != null && !_isScanningOcr)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            '⚡ Fields Pre-filled from Document Scan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review the auto-filled details below. Make any adjustments before tapping Confirm & Save.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Document Title *',
                  hintText: 'e.g. Dubai Trade Licence 2026',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description_outlined),
                  suffixIcon: _ocrResult?.title != null
                      ? const Tooltip(
                          message: 'Auto-filled from OCR scan',
                          child: Icon(Icons.bolt, color: Colors.amber, size: 20),
                        )
                      : null,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a document title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentTypeMeta>(
                initialValue: _docType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Document Category',
                  border: const OutlineInputBorder(),
                  suffixIcon: _ocrResult?.documentType != null
                      ? const Tooltip(
                          message: 'Auto-filled from OCR scan',
                          child: Icon(Icons.bolt, color: Colors.amber, size: 20),
                        )
                      : null,
                ),
                items: DocumentTypeRegistry.instance.typesForPicker.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 20, color: t.primaryColor),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            t.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _docType = val);
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addCustomType,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('New document type'),
                ),
              ),
              const SizedBox(height: 16),

              // Emirate Dropdown
              DropdownButtonFormField<UaeEmirate>(
                value: _selectedEmirate,
                decoration: InputDecoration(
                  labelText: 'Emirate / Jurisdiction',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.map_rounded),
                  suffixIcon: _ocrResult?.emirate != null
                      ? const Tooltip(
                          message: 'Auto-filled from OCR scan',
                          child: Icon(Icons.bolt, color: Colors.amber, size: 20),
                        )
                      : null,
                ),
                items: UaeEmirate.values.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedEmirate = val;
                      final list = _emirateAuthorities[val] ?? [];
                      _selectedAuthority = list.isNotEmpty ? list.first : 'OTHER_CUSTOM';
                      _isCustomAuthority = _selectedAuthority == 'OTHER_CUSTOM';
                      _locationController.text = _isCustomAuthority ? '' : _selectedAuthority;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Authority Dropdown
              DropdownButtonFormField<String>(
                value: _selectedAuthority,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Issuing Authority',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: [
                  ...?_emirateAuthorities[_selectedEmirate]?.map((auth) {
                    return DropdownMenuItem(
                      value: auth,
                      child: Text(
                        auth,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  const DropdownMenuItem(
                    value: 'OTHER_CUSTOM',
                    child: Text('Other / Custom Authority...'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    if (val == 'OTHER_CUSTOM') {
                      setState(() {
                        _selectedAuthority = 'OTHER_CUSTOM';
                        _isCustomAuthority = true;
                        _locationController.text = '';
                      });
                    } else {
                      setState(() {
                        _selectedAuthority = val;
                        _isCustomAuthority = false;
                        _locationController.text = val;
                      });
                    }
                  }
                },
              ),

              if (_isCustomAuthority) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Specify Custom Authority *',
                    hintText: 'e.g. Freezone Authority Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_location_alt_outlined),
                  ),
                  validator: (val) {
                    if (_isCustomAuthority && (val == null || val.trim().isEmpty)) {
                      return 'Please specify the authority name';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16),
              InkWell(
                onTap: _pickExpiryDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expiry Date *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: _ocrResult?.expiryDate != null
                        ? const Tooltip(
                            message: 'Auto-filled from OCR scan',
                            child: Icon(Icons.bolt, color: Colors.amber, size: 20),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMMM yyyy').format(_expiresAt),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: daysRemaining <= 30
                              ? Colors.red.shade100
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$daysRemaining days left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: daysRemaining <= 30
                                ? Colors.red.shade900
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Estimated Renewal Fee (AED)',
                  hintText: 'e.g. 1500',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes & Information (Optional)',
                  hintText: 'Add license number, TRN, or renewal steps...',
                  border: const OutlineInputBorder(),
                  suffixIcon: _ocrResult?.documentNumber != null
                      ? const Tooltip(
                          message: 'License/Document number detected',
                          child: Icon(Icons.bolt, color: Colors.amber, size: 20),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveDocument,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_ocrResult != null
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_rounded),
                label: Text(_isSaving
                    ? 'Saving...'
                    : _ocrResult != null
                        ? 'Confirm & Save Document'
                        : 'Save document'),
                style: FilledButton.styleFrom(
                  backgroundColor: _ocrResult != null ? Colors.green.shade700 : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
