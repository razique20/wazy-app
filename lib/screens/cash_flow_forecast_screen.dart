import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cash_flow_forecast_chart.dart';

class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});

  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  List<FinanceTransaction> _transactions = [];
  List<RecurringTransaction> _recurring = [];
  List<ExpiryItem> _items = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'renewals', 'recurring'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await FinanceService.instance.init();
    final items = await DocumentScannerService().getAllItems();
    if (!mounted) return;
    setState(() {
      _transactions = FinanceService.instance.activeTransactions;
      _recurring = FinanceService.instance.activeRecurring;
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final forecast = FinanceMath.calculate90DayCashFlow(
      transactions: _transactions,
      recurringTemplates: _recurring,
      expiryItems: _items,
    );

    // Filter points with events
    final pointsWithEvents = forecast.points.where((p) => p.events.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('90-Day Cash-Flow Forecast'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Forecast',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Chart Card
                CashFlowForecastCard(forecast: forecast),
                const SizedBox(height: 24),

                // Events Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Scheduled Events',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${pointsWithEvents.length} active days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter Segmented Buttons
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'all',
                      label: Text('All Events'),
                      icon: Icon(Icons.list_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'renewals',
                      label: Text('Renewals Only'),
                      icon: Icon(Icons.assignment_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'recurring',
                      label: Text('Recurring'),
                      icon: Icon(Icons.repeat_rounded, size: 16),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _filter = selected.first;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Event Days List
                if (pointsWithEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2430) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No scheduled recurring payments or document renewals in the next 90 days.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final point in pointsWithEvents) ...[
                    _buildDayEventCard(theme, point, isDark),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
    );
  }

  Widget _buildDayEventCard(ThemeData theme, CashFlowPoint point, bool isDark) {
    final filteredEvents = point.events.where((ev) {
      if (_filter == 'renewals') return ev.isDocumentRenewal;
      if (_filter == 'recurring') return !ev.isDocumentRenewal;
      return true;
    }).toList();

    if (filteredEvents.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FinavigColors.violetAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        DateFormat('MMM d').format(point.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FinavigColors.violetAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE').format(point.date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Balance: ${MoneyFormat.aed(point.balance)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: point.balance >= 0 ? FinavigColors.safe : FinavigColors.danger,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Events List
            for (final ev in filteredEvents)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (ev.isDocumentRenewal
                                ? FinavigColors.caution
                                : (ev.kind == FinanceKind.income ? FinavigColors.safe : Colors.red))
                            .withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ev.isDocumentRenewal
                            ? Icons.assignment_rounded
                            : (ev.kind == FinanceKind.income
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_outward_rounded),
                        size: 14,
                        color: ev.isDocumentRenewal
                            ? FinavigColors.caution
                            : (ev.kind == FinanceKind.income ? FinavigColors.safe : Colors.red),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ev.isDocumentRenewal
                                ? 'Document Renewal Fee'
                                : '${ev.kind.label} Schedule',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${ev.kind == FinanceKind.income ? '+' : '-'}${MoneyFormat.aed(ev.amount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ev.kind == FinanceKind.income ? FinavigColors.safe : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
