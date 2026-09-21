import 'package:flutter/material.dart';

import '../models/finance.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/indicators/empty_state_illustration.dart';
import 'money_screen.dart';

/// Savings envelopes page opened from the Home categories grid: set aside
/// money for upcoming renewals — tracked only, no real money moves.
class EnvelopesScreen extends StatefulWidget {
  const EnvelopesScreen({super.key});

  @override
  State<EnvelopesScreen> createState() => _EnvelopesScreenState();
}

class _EnvelopesScreenState extends State<EnvelopesScreen> {
  List<SavingsEnvelope> _envelopes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FinanceService.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    FinanceService.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    await FinanceService.instance.init();
    if (!mounted) return;
    setState(() {
      _envelopes = FinanceService.instance.activeEnvelopes;
      _loading = false;
    });
  }

  Future<void> _showEnvelopeSheet() async {
    final result = await showModalBottomSheet<(String, double, double)>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EnvelopeFormSheet(),
    );
    if (result == null) return;
    await FinanceService.instance.addEnvelope(result.$1, result.$2, result.$3);
    await _reload();
  }

  Future<void> _adjustEnvelope(SavingsEnvelope envelope, double delta) async {
    await FinanceService.instance.adjustEnvelope(envelope.id, delta);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delta > 0
              ? 'Set aside ${MoneyFormat.aed(delta)} in ${envelope.name}'
              : 'Withdrew ${MoneyFormat.aed(-delta)} from ${envelope.name}',
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Savings envelopes')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'envelopes_add',
        onPressed: _showEnvelopeSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New envelope',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: WazyColors.violetAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  if (_envelopes.isEmpty)
                    _hintCard(
                      theme,
                      'Set aside money for big renewals — tracked only, no real money moves. Tap "New envelope" to start one.',
                      scene: EmptyStateScene.wallet,
                    )
                  else
                    ..._envelopes.map(
                      (envelope) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EnvelopeCard(
                          envelope: envelope,
                          onAdd: () => _adjustEnvelope(envelope, 100),
                          onWithdraw: () => _adjustEnvelope(envelope, -100),
                          onDelete: () =>
                              FinanceService.instance.deleteEnvelope(
                            envelope.id,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _hintCard(ThemeData theme, String text,
      {EmptyStateScene scene = EmptyStateScene.wallet}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(scene: scene, size: 88),
          const SizedBox(height: 10),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
