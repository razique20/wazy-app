import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/expiry_item.dart';
import '../../services/collection_service.dart';
import '../../services/companion_document_factory.dart';
import '../../services/companion_suggestion_service.dart';
import '../../services/document_scanner_service.dart';
import 'companion_suggestion_sheet.dart';
import '../../services/natural_language_parser_service.dart';
import '../../services/voice_input_service.dart';
import 'upgrade_dialog.dart';

/// Modal dialog allowing users to type freeform text to create a document item.
class NaturalLanguageAddDialog extends StatefulWidget {
  const NaturalLanguageAddDialog({super.key});

  static Future<ExpiryItem?> show(BuildContext context) {
    return showModalBottomSheet<ExpiryItem>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const NaturalLanguageAddDialog(),
    );
  }

  @override
  State<NaturalLanguageAddDialog> createState() => _NaturalLanguageAddDialogState();
}

class _NaturalLanguageAddDialogState extends State<NaturalLanguageAddDialog> {
  late final TextEditingController _inputController;
  ParsedNaturalLanguageItem? _parsed;
  bool _isSaving = false;

  // Voice input state
  bool _isListening = false;
  String _voicePartial = '';
  StreamSubscription<VoiceStatus>? _voiceStatusSub;
  StreamSubscription<VoiceUpdate>? _voiceTranscriptSub;

  final List<String> _samplePrompts = [
    'Add my trade licence, expires 12 March 2027 cost 1500 AED',
    'Dubai Ejari contract expires in 60 days fee 2500 AED',
    'Visa renewal for John Doe expires 2026-11-15',
    'Vehicle Mulkiya expires next month cost 800 AED Abu Dhabi',
  ];

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _inputController.addListener(_onInputChanged);
    _voiceStatusSub = VoiceInputService.instance.statusStream.listen(_onVoiceStatus);
    _voiceTranscriptSub =
        VoiceInputService.instance.transcriptStream.listen(_onVoiceUpdate);
  }

  @override
  void dispose() {
    _voiceStatusSub?.cancel();
    _voiceTranscriptSub?.cancel();
    VoiceInputService.instance.stopListening();
    _inputController.dispose();
    super.dispose();
  }

  void _onVoiceStatus(VoiceStatus status) {
    if (!mounted) return;
    setState(() {
      _isListening = VoiceInputService.instance.isListening;
      if (!_isListening) _voicePartial = '';
    });
    if (status == VoiceStatus.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            VoiceInputService.instance.lastError ??
                'Voice input is not available.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onVoiceUpdate(VoiceUpdate update) {
    if (!mounted) return;
    if (update.text.isNotEmpty) {
      // Final transcript — normalize spoken numbers/currency and populate the
      // input; the controller listener runs the NL parser automatically.
      final normalized = VoiceInputService.normalizeTranscript(update.text);
      _inputController.text = normalized;
      setState(() => _voicePartial = '');
    } else if (update.partialText.isNotEmpty) {
      setState(() {
        _voicePartial = VoiceInputService.normalizeTranscript(update.partialText);
      });
    }
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await VoiceInputService.instance.stopListening();
      return;
    }
    FocusScope.of(context).unfocus();
    final started = await VoiceInputService.instance.startListening();
    if (started && mounted) {
      setState(() {
        _isListening = true;
        _voicePartial = '';
      });
    }
  }

  void _onInputChanged() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() => _parsed = null);
    } else {
      setState(() {
        _parsed = NaturalLanguageParserService.instance.parse(text);
      });
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

  Future<void> _quickSave() async {
    if (_parsed == null) return;
    setState(() => _isSaving = true);

    try {
      final item = _parsed!;
      final now = DateTime.now();
      final daysOffset = item.expiryDate.difference(now).inDays;
      final docId = const Uuid().v4();

      final newItem = ExpiryItem(
        id: docId,
        collectionId: DocumentCollectionService.instance.activeCollectionId,
        displayName: item.title,
        docType: item.docType,
        expiryDate: DateFormat('dd MMM yyyy').format(item.expiryDate),
        daysRemaining: daysOffset,
        isExpired: daysOffset < 0,
        isNotified: false,
        notifiedDays: null,
        description: 'Added via Natural Language Quick Add: "${item.rawInput}"',
        location: item.authority,
        reminderStatus: _determineReminderStatus(daysOffset),
        urgency: _determineUrgency(daysOffset),
        assignedTo: null,
        documentDate: DateFormat('dd MMM yyyy').format(now),
        renewalFee: item.renewalFee,
        renewalSteps: [
          'Gather required documentation',
          'Prepare renewal application',
          'Submit to relevant authority',
          'Pay renewal fees',
          'Receive renewed document',
        ],
        renewalAuthorities: [item.authority],
        renewalWarning: daysOffset <= 30 ? 'Expires soon — renew to avoid penalties' : null,
        expiresAt: item.expiryDate,
      );

      // Track 1 gate: respect the Free plan's 10-document quota.
      if (!await enforceDocumentLimit(context)) return;

      await DocumentScannerService.instance.addItem(newItem);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newItem.displayName} saved & tracked!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, newItem);
      unawaited(_maybeSuggestCompanions(newItem));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save document: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _maybeSuggestCompanions(ExpiryItem newItem) async {
    await CompanionSuggestionSheet.maybeSuggestCompanions(context, newItem);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
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
                child: Icon(Icons.bolt_rounded, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Natural-Language Quick Add',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Type or paste details in plain English',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            autofocus: true,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Add my trade licence, expires 12 March 2027 cost 1500 AED',
              border: const OutlineInputBorder(),
              suffixIcon: _inputController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => _inputController.clear(),
                    )
                  : IconButton(
                      tooltip: 'Speak instead of typing',
                      icon: Icon(
                        _isListening
                            ? Icons.stop_circle_rounded
                            : Icons.mic_rounded,
                        color: _isListening ? Colors.red : null,
                      ),
                      onPressed: _toggleVoice,
                    ),
            ),
          ),

          // Live voice banner
          if (_isListening)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _voicePartial.isEmpty
                          ? 'Listening… say e.g. "Add my trade licence, expires 12 March 2027 cost 1500 AED"'
                          : _voicePartial,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: _voicePartial.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => VoiceInputService.instance.stopListening(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Sample chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _samplePrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      prompt,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      _inputController.text = prompt;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Live Parsed Preview
          if (_parsed != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_parsed!.docType.icon, color: _parsed!.docType.primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _parsed!.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _parsed!.docType.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _parsed!.docType.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _parsed!.docType.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Expiry: ${DateFormat('dd MMMM yyyy').format(_parsed!.expiryDate)}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        '${_parsed!.expiryDate.difference(DateTime.now()).inDays} days left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_parsed!.renewalFee != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Estimated Fee: ${_parsed!.renewalFee!.toStringAsFixed(0)} AED',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.map_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Authority: ${_parsed!.authority}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/document-scan');
                    },
                    child: const Text('Open Full Form'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _quickSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Confirm & Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
