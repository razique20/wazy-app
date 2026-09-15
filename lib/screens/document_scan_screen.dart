import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/document_collection.dart';
import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../services/document_scanner_service.dart';

/// Full screen form to add a new document and track its expiry date & renewal cost.
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

  DocumentType _docType = DocumentType.tradeLicence;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _feeController = TextEditingController();
    _locationController = TextEditingController(text: 'UAE');
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

      final item = ExpiryItem(
        id: const Uuid().v4(),
        collectionId: DocumentCollection.personalId, // re-scoped on save in service
        displayName: _titleController.text.trim(),
        docType: _docType,
        expiryDate: DateFormat('dd MMM yyyy').format(_expiresAt),
        daysRemaining: daysOffset,
        isExpired: daysOffset < 0,
        isNotified: false,
        notifiedDays: null,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty ? 'UAE' : _locationController.text.trim(),
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
        renewalAuthorities: ['Relevant Authority'],
        renewalWarning: daysOffset <= 30 ? 'Expires soon — renew to avoid penalties' : null,
        expiresAt: _expiresAt,
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
        title: const Text('Add document'),
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
                'Enter details below to track expiry dates and renewal fees.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Document Title *',
                  hintText: 'e.g. Dubai Trade Licence 2026',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a document title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentType>(
                initialValue: _docType,
                decoration: const InputDecoration(
                  labelText: 'Document Category',
                  border: OutlineInputBorder(),
                ),
                items: DocumentType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 20, color: t.primaryColor),
                        const SizedBox(width: 10),
                        Text(t.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _docType = val);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickExpiryDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_rounded),
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
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Issuer / Authority',
                  hintText: 'e.g. Dubai DED / RERA / GDRFA',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes & Information (Optional)',
                  hintText: 'Add license number, TRN, or renewal steps...',
                  border: OutlineInputBorder(),
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
                    : const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save document'),
                style: FilledButton.styleFrom(
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
