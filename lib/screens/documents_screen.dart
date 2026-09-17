import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/document_scanner_service.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/indicators/department_logo.dart';
import '../widgets/dialogs/natural_language_add_dialog.dart';

/// Documents tab (Tier 1): the full expiry-tracking workspace — search,
/// filters and detailed cards with inline actions.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

enum _DocFilter { all, critical, upcoming, later, expired }

enum _DocSort { dueDate, urgency, name, fee }

extension _DocSortX on _DocSort {
  String get label {
    switch (this) {
      case _DocSort.dueDate:
        return 'Due date';
      case _DocSort.urgency:
        return 'Urgency';
      case _DocSort.name:
        return 'Name';
      case _DocSort.fee:
        return 'Renewal fee';
    }
  }

  IconData get icon {
    switch (this) {
      case _DocSort.dueDate:
        return Icons.event_rounded;
      case _DocSort.urgency:
        return Icons.priority_high_rounded;
      case _DocSort.name:
        return Icons.sort_by_alpha_rounded;
      case _DocSort.fee:
        return Icons.payments_rounded;
    }
  }
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<ExpiryItem> _items = [];
  bool _loading = true;
  String _query = '';
  _DocFilter _filter = _DocFilter.all;
  _DocSort _sort = _DocSort.dueDate;
  DocumentTypeMeta? _typeFilter;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    DocumentScannerService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    DocumentScannerService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _loadData();
  }

  Future<void> _loadData() async {
    // Include expired documents so the "Expired" filter and the insights
    // header can show documents that already lapsed.
    final items = await DocumentScannerService().getAllItems(includeExpired: true);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  List<ExpiryItem> get _filtered {
    final now = DateTime.now();
    final list = _items.where((i) {
      if (!i.isActive && !i.isExpired) return false;
      if (_query.isNotEmpty &&
          !i.displayName.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_typeFilter != null && i.docType.key != _typeFilter!.key) return false;
      switch (_filter) {
        case _DocFilter.all:
          return true;
        case _DocFilter.critical:
          return i.daysRemaining <= 7;
        case _DocFilter.upcoming:
          return i.daysRemaining > 7 && i.daysRemaining <= 30;
        case _DocFilter.later:
          return i.daysRemaining > 30;
        case _DocFilter.expired:
          return i.expiresAt.isBefore(now) || i.daysRemaining < 0;
      }
    }).toList();

    switch (_sort) {
      case _DocSort.dueDate:
        list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      case _DocSort.urgency:
        list.sort((a, b) {
          final byPriority = b.urgency.priority.compareTo(a.urgency.priority);
          if (byPriority != 0) return byPriority;
          return a.expiresAt.compareTo(b.expiresAt);
        });
      case _DocSort.name:
        list.sort(
            (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      case _DocSort.fee:
        list.sort((a, b) {
          final aFee = a.renewalFee ?? 0;
          final bFee = b.renewalFee ?? 0;
          if (bFee != aFee) return bFee.compareTo(aFee);
          return a.expiresAt.compareTo(b.expiresAt);
        });
    }
    return list;
  }

  /// Nearest document needing action — shown in the insights header.
  ExpiryItem? get _nextDue {
    final now = DateTime.now();
    final active = _items.where((i) => i.isActive && i.expiresAt.isAfter(now)).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return active.isEmpty ? null : active.first;
  }

  double get _totalUpcomingFees {
    final now = DateTime.now();
    return _items
        .where((i) =>
            i.isActive && i.expiresAt.isAfter(now) && (i.renewalFee ?? 0) > 0)
        .fold(0.0, (sum, i) => sum + i.renewalFee!);
  }

  bool get _hasActiveFilters =>
      _filter != _DocFilter.all || _typeFilter != null || _query.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _filter = _DocFilter.all;
      _typeFilter = null;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_items);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            tooltip: 'Quick Add with Natural Language',
            onPressed: () async {
              final created = await NaturalLanguageAddDialog.show(context);
              if (created != null) _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.travel_explore_rounded),
            tooltip: 'Search all documents',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          PopupMenuButton<_DocSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort by',
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (ctx) => _DocSort.values
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(
                          s.icon,
                          size: 18,
                          color: _sort == s
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontWeight: _sort == s
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (_sort == s)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: searchField(),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Filter chips row
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(
                        children: [
                          _statusChip(theme, 'All', _DocFilter.all,
                              _items.where((i) => i.isActive || i.isExpired).length),
                          _statusChip(theme, 'Critical', _DocFilter.critical,
                              urgency.criticalCount),
                          _statusChip(theme, '≤30 days', _DocFilter.upcoming,
                              urgency.highCount),
                          _statusChip(theme, 'Later', _DocFilter.later,
                              urgency.mediumCount + urgency.lowCount),
                          _statusChip(theme, 'Expired', _DocFilter.expired,
                              _items.where((i) => !i.isActive && i.isExpired).length),
                        ],
                      ),
                    ),
                  ),
                  // Type filter chips
                  if (_showFilters)
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Row(
                          children: [
                            _typeChip(theme, null, 'All types'),
                            ...DocumentTypeRegistry.instance.typesForPicker
                                .map((t) => _typeChip(theme, t, t.displayName)),
                          ],
                        ),
                      ),
                    ),
                  // Clear filters
                  if (_hasActiveFilters)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ActionChip(
                            avatar: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.brightness == Brightness.dark
                                  ? WazyColors.textSecondary
                                  : WazyColors.textPrimaryLight,
                            ),
                            label: Text(
                              'Clear filters',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? WazyColors.textPrimary
                                    : WazyColors.textPrimaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: _clearFilters,
                            backgroundColor: theme.brightness == Brightness.dark
                                ? WazyColors.slate
                                : WazyColors.cloud,
                            side: BorderSide(
                              color: theme.brightness == Brightness.dark
                                  ? WazyColors.slateLight.withOpacity(0.3)
                                  : WazyColors.fog,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Insights header
                  SliverToBoxAdapter(
                    child: _InsightsHeader(
                      count: filtered.length,
                      urgency: urgency,
                      nextDue: _nextDue,
                      totalUpcomingFees: _totalUpcomingFees,
                    ),
                  ),
                  // Cards
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DocumentCard(
                              item: filtered[index],
                              onTap: () async {
                                await context
                                    .push('/document/${filtered[index].id}');
                                await _loadData();
                              },
                              onAction: () =>
                                  _showActionSheet(context, filtered[index]),
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 115),
        child: FloatingActionButton.extended(
          heroTag: 'documents_add',
          onPressed: () async {
            await context.push('/scan');
            await _loadData();
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Document'),
          backgroundColor: WazyColors.navyPrimary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget searchField() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(
        color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search documents…',
        hintStyle: TextStyle(
          color: isDark ? WazyColors.textMuted : WazyColors.textMutedLight,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight,
                ),
                onPressed: () => setState(() => _query = ''),
              ),
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : WazyColors.cloud,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _statusChip(
      ThemeData theme, String label, _DocFilter filter, int count) {
    final isDark = theme.brightness == Brightness.dark;
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected
                ? (isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary)
                : (isDark ? WazyColors.textSecondary : WazyColors.textPrimaryLight),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
        showCheckmark: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: isDark ? WazyColors.slate : WazyColors.cloud,
        selectedColor: isDark
            ? WazyColors.navyPrimary.withOpacity(0.4)
            : WazyColors.navyPrimary.withOpacity(0.12),
        side: BorderSide(
          color: selected
              ? (isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary)
              : (isDark ? WazyColors.slateLight.withOpacity(0.3) : WazyColors.fog),
        ),
      ),
    );
  }

  Widget _typeChip(ThemeData theme, DocumentTypeMeta? type, String label) {
    final isDark = theme.brightness == Brightness.dark;
    final selected = _typeFilter?.key == type?.key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: type != null
            ? Icon(
                type.icon,
                size: 16,
                color: selected
                    ? (isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary)
                    : type.primaryColor,
              )
            : null,
        label: Text(
          label,
          style: TextStyle(
            color: selected
                ? (isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary)
                : (isDark ? WazyColors.textSecondary : WazyColors.textPrimaryLight),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = type),
        showCheckmark: false,
        backgroundColor: isDark ? WazyColors.slate : WazyColors.cloud,
        selectedColor: isDark
            ? WazyColors.navyPrimary.withOpacity(0.4)
            : WazyColors.navyPrimary.withOpacity(0.12),
        side: BorderSide(
          color: selected
              ? (isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary)
              : (isDark ? WazyColors.slateLight.withOpacity(0.3) : WazyColors.fog),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasActiveFilters ? Icons.search_off : Icons.inbox_outlined,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters ? 'No documents match' : 'No documents yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          if (!_hasActiveFilters)
            FilledButton.icon(
              onPressed: () async {
                await context.push('/scan');
                await _loadData();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add first document'),
            )
          else
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  void _showActionSheet(BuildContext context, ExpiryItem item) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.daysRemaining} days left',
                    style: TextStyle(
                      color: item.daysRemaining <= 7
                          ? Colors.red
                          : item.daysRemaining <= 30
                              ? Colors.orange
                              : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.event_available_rounded,
                  color: Colors.green),
              title: const Text('Mark as renewed'),
              subtitle: const Text('Reset the expiry clock'),
              onTap: () => Navigator.pop(ctx, 'renewed'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_calendar_rounded, color: Colors.blue),
              title: const Text('Update expiry date'),
              subtitle: const Text('Correct or adjust the date'),
              onTap: () => Navigator.pop(ctx, 'date'),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_rounded,
                  color: Colors.indigo),
              title: const Text('Assign to…'),
              subtitle: const Text('Responsible team member'),
              onTap: () => Navigator.pop(ctx, 'assign'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete document'),
              subtitle: const Text('Remove from tracking'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    ).then((action) {
      if (action == null || !mounted) return;
      switch (action as String) {
        case 'renewed':
          _markRenewed(item);
        case 'date':
          _updateDate(item);
        case 'assign':
          _assign(item);
        case 'delete':
          _confirmDelete(item);
      }
    });
  }

  Future<void> _markRenewed(ExpiryItem item) async {
    await DocumentScannerService.instance.markAsRenewed(item.id);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.displayName} marked as renewed ✓'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _updateDate(ExpiryItem item) async {
    final date = await showDatePicker(
      context: context,
      initialDate: item.expiresAt,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (date == null) return;
    await DocumentScannerService.instance.updateExpiryDate(item.id, date);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Expiry updated to ${DateFormat('dd MMM yyyy').format(date)}',
        ),
      ),
    );
  }

  Future<void> _assign(ExpiryItem item) async {
    final controller = TextEditingController(text: item.assignedTo ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign to'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Team member name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await DocumentScannerService.instance.assignTo(item.id, name);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigned to $name')),
    );
  }

  Future<void> _confirmDelete(ExpiryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '"${item.displayName}" will be removed from tracking. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DocumentScannerService.instance.removeItem(item.id);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.displayName} deleted')),
    );
  }
}

// ====================================================================
// Insights header — explains what the list means at a glance
// ====================================================================

class _InsightsHeader extends StatelessWidget {
  final int count;
  final UrgencySnapshot urgency;
  final ExpiryItem? nextDue;
  final double totalUpcomingFees;

  const _InsightsHeader({
    required this.count,
    required this.urgency,
    required this.nextDue,
    required this.totalUpcomingFees,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pending = urgency.pendingActions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.35)
              : WazyColors.cloud,
          borderRadius: BorderRadius.circular(14),
          border: isDark ? null : Border.all(color: WazyColors.fog.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pending == 0
                        ? '$count tracked · all on track'
                        : '$count tracked · $pending need attention',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
                    ),
                  ),
                ),
                if (urgency.criticalCount > 0)
                  _insightPill(
                    theme,
                    '${urgency.criticalCount} critical',
                    isDark ? Colors.redAccent : const Color(0xFFDC2626),
                  ),
                if (urgency.highCount > 0) ...[
                  const SizedBox(width: 6),
                  _insightPill(
                    theme,
                    '${urgency.highCount} due ≤30d',
                    isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _insightItem(
                    theme,
                    icon: Icons.event_available_rounded,
                    label: 'Next due',
                    value: nextDue == null
                        ? '—'
                        : '${nextDue!.displayName} · ${nextDue!.daysRemaining}d',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _insightItem(
                    theme,
                    icon: Icons.payments_rounded,
                    label: 'Upcoming fees',
                    value: totalUpcomingFees > 0
                        ? MoneyFormat.aed(totalUpcomingFees, symbol: 'AED ')
                        : '—',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightPill(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _insightItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? WazyColors.textMuted : WazyColors.textSecondaryLight;
    final valueColor = isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight;

    return Row(
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Detailed document card
// ====================================================================

class _DocumentCard extends StatelessWidget {
  final ExpiryItem item;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const _DocumentCard({
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  Color _accentColor(bool isDark) {
    final days = item.daysRemaining;
    if (isDark) {
      if (days < 0) return WazyColors.danger;
      if (days <= 7) return WazyColors.danger;
      if (days <= 30) return WazyColors.warning;
      if (days <= 60) return WazyColors.caution;
      return WazyColors.safe;
    } else {
      if (days < 0) return const Color(0xFFDC2626); // Dark Red
      if (days <= 7) return const Color(0xFFDC2626);
      if (days <= 30) return const Color(0xFFD97706); // Dark Amber/Orange
      if (days <= 60) return const Color(0xFFB45309); // Dark Ochre/Gold
      return const Color(0xFF059669); // Dark Emerald Green
    }
  }

  String get _statusLabel {
    final days = item.daysRemaining;
    if (days < 0) return 'Expired ${-days}d ago';
    if (days <= 7) return 'Due now';
    if (days <= 30) return 'This month';
    if (days <= 60) return 'Within 60 days';
    return 'On track';
  }

  /// Fraction of the tracking window already elapsed (0 → just renewed,
  /// 1 → expiring now). Approximates urgency visually.
  double get _timeProgress {
    if (item.daysRemaining < 0) return 1.0;
    final window = item.docType.typicalRenewalDays;
    if (window <= 0) return 0;
    return (1 - item.daysRemaining / window).clamp(0.0, 1.0);
  }

  /// Human explanation of what the reminder tier means.
  String get _reminderText {
    switch (item.reminderStatus) {
      case 4:
        return 'Final alert — renew immediately';
      case 3:
        return 'Active reminders — renew this month';
      case 2:
        return 'Early reminders — plan ahead';
      case 1:
        return 'Monitoring — plenty of time left';
      default:
        return 'No reminders yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentColor(isDark);

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.35)
          : Colors.white,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? WazyColors.slateLight.withOpacity(0.3)
                  : WazyColors.fog.withOpacity(0.5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  DepartmentLogo(
                    item: item,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.docType.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? WazyColors.textMuted : WazyColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.daysRemaining < 0
                            ? '${-item.daysRemaining}d overdue'
                            : '${item.daysRemaining}d left',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: accent,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(isDark ? 0.15 : 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Time-remaining progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _timeProgress,
                  minHeight: 5,
                  backgroundColor: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : WazyColors.mist,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _timeProgress >= 1.0
                    ? 'Renewal window fully elapsed'
                    : '${(100 - _timeProgress * 100).toStringAsFixed(0)}% of the renewal window left',
                style: TextStyle(
                  color: isDark ? WazyColors.textMuted : WazyColors.textMutedLight,
                  fontSize: 10,
                ),
              ),
              // Detail rows
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDark
                    ? WazyColors.slateLight.withOpacity(0.3)
                    : WazyColors.fog.withOpacity(0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _detail(
                    theme,
                    Icons.calendar_today_rounded,
                    'Expires ${ExpiryItem.formatDate(item.expiresAt)}',
                  ),
                  _detail(
                    theme,
                    Icons.account_balance_rounded,
                    item.docType.renewalAuthority,
                  ),
                  if (item.location != null)
                    _detail(
                      theme,
                      Icons.location_on_outlined,
                      item.location!,
                    ),
                  if (item.assignedTo != null)
                    _detail(
                      theme,
                      Icons.person_outline_rounded,
                      'Owner: ${item.assignedTo}',
                    ),
                  if (item.renewalFee != null && item.renewalFee! > 0)
                    _detail(
                      theme,
                      Icons.payments_outlined,
                      'Renewal fee AED ${item.renewalFee!.toStringAsFixed(0)}',
                    ),
                  _detail(
                    theme,
                    Icons.notifications_active_outlined,
                    _reminderText,
                  ),
                ],
              ),
              // Renewal warning
              if (item.daysRemaining <= 30 && item.renewalWarning != null) ...[
                const SizedBox(height: 8),
                Text(
                  item.renewalWarning!,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Quick action: mark renewed
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 16,
                        color: isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary,
                      ),
                      label: Text(
                        'Actions',
                        style: TextStyle(
                          color: isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(
                          color: isDark
                              ? WazyColors.cyanSecondary.withOpacity(0.4)
                              : WazyColors.navyPrimary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(ThemeData theme, IconData icon, String text) {
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? WazyColors.textMuted : WazyColors.textSecondaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: isDark ? WazyColors.textSecondary : WazyColors.textPrimaryLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
