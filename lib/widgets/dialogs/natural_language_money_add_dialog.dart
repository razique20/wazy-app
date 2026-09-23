import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/finance.dart';
import '../../services/collection_service.dart';
import '../../services/finance_service.dart';
import '../../services/natural_language_parser_service.dart';
import '../../services/voice_input_service.dart';

/// Modal dialog allowing users to type freeform text to log an expense, income, or recurring money item.
class NaturalLanguageMoneyAddDialog extends StatefulWidget {
  const NaturalLanguageMoneyAddDialog({super.key});

  static Future<FinanceTransaction?> show(BuildContext context) {
    return showModalBottomSheet<FinanceTransaction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const NaturalLanguageMoneyAddDialog(),
    );
  }

  @override
  State<NaturalLanguageMoneyAddDialog> createState() =>
      _NaturalLanguageMoneyAddDialogState();
}

class _NaturalLanguageMoneyAddDialogState
    extends State<NaturalLanguageMoneyAddDialog> {
  late final TextEditingController _inputController;
  ParsedMoneyItem? _parsed;
  bool _isSaving = false;

  // Voice input state
  bool _isListening = false;
  String _voicePartial = '';
  StreamSubscription<VoiceStatus>? _voiceStatusSub;
  StreamSubscription<VoiceUpdate>? _voiceTranscriptSub;

  List<String> get _samplePrompts {
    final c = DocumentCollectionService.instance.activeCurrency;
    return [
      'Paid 450 $c for DEWA electricity yesterday',
      'Received 12,000 $c client payment from Acme',
      'Spent 85 $c on Uber transport today',
      'Office rent 15,000 $c recurring monthly on 1st',
    ];
  }

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
        _parsed = NaturalLanguageParserService.instance.parseMoney(text);
      });
    }
  }

  Future<void> _quickSave() async {
    if (_parsed == null) return;
    setState(() => _isSaving = true);

    try {
      final item = _parsed!;
      final collectionId =
          DocumentCollectionService.instance.activeCollectionId;
      final txId = const Uuid().v4();

      final newTransaction = FinanceTransaction(
        id: txId,
        collectionId: collectionId,
        kind: item.kind,
        category: item.category,
        title: item.title,
        amount: item.amount,
        currency: item.currency,
        occurredAt: item.occurredAt,
        note: 'Added via Natural Language Quick Add: "${item.rawInput}"',
      );

      if (item.isRecurring) {
        final recId = const Uuid().v4();
        final recurringTemplate = RecurringTransaction(
          id: recId,
          collectionId: collectionId,
          kind: item.kind,
          category: item.category,
          title: item.title,
          amount: item.amount,
          currency: item.currency,
          frequency: item.frequency,
          dayOfMonth: item.dayOfMonth,
          startDate: item.occurredAt,
        );
        await FinanceService.instance.addRecurring(recurringTemplate);
      } else {
        // Check duplicate expense
        final existing = FinanceService.instance.activeTransactions;
        final duplicate = FinanceMath.findDuplicateTransaction(existing, newTransaction);
        if (duplicate != null && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Possible Duplicate Transaction'),
              content: Text(
                'A similar expense "${duplicate.title}" (${MoneyFormat.aed(duplicate.amount)}) was already logged. Log this record anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Log Anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) {
            setState(() => _isSaving = false);
            return;
          }
        }

        await FinanceService.instance.addTransaction(newTransaction);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.kind == FinanceKind.income ? "Income" : "Expense"} "${item.title}" (${MoneyFormat.aed(item.amount)}) saved! ✓',
          ),
          backgroundColor: item.kind == FinanceKind.income
              ? Colors.green
              : Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.pop(context, newTransaction);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save record: $e'),
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
                child: Icon(Icons.bolt_rounded,
                    color: theme.colorScheme.onPrimaryContainer),
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
                      'Type expenses or income in plain English',
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
              hintText:
                  'e.g. Paid 450 ${DocumentCollectionService.instance.activeCurrency} for DEWA electricity yesterday',
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
                          ? 'Listening… say e.g. "Paid 450 ${DocumentCollectionService.instance.activeCurrency} for DEWA yesterday"'
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

          // Live Parsed Preview Card
          if (_parsed != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _parsed!.category.icon,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_parsed!.kind == FinanceKind.income
                                  ? Colors.green
                                  : Colors.red)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _parsed!.kind.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _parsed!.kind == FinanceKind.income
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            MoneyFormat.aed(_parsed!.amount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _parsed!.kind == FinanceKind.income
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _parsed!.category.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: theme.colorScheme.outline),
                      const SizedBox(width: 6),
                      Text(
                        'Date: ${DateFormat('dd MMMM yyyy').format(_parsed!.occurredAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (_parsed!.isRecurring) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Recurring (${_parsed!.frequency.label})',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _quickSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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
