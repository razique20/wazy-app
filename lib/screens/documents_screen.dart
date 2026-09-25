import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/document_scanner_service.dart';
import '../services/collection_service.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/bento_icon_tile.dart';
import '../widgets/indicators/department_logo.dart';
import '../widgets/indicators/empty_state_illustration.dart';
import '../widgets/dialogs/natural_language_add_dialog.dart';
import '../widgets/dialogs/renew_document_dialog.dart';
import '../widgets/dialogs/upgrade_dialog.dart';

/// Documents tab (Tier 1): the full expiry-tracking workspace.
///
/// Same anatomy as the redesigned Home tab: a navy hero header carrying the
/// greeting, a live count, and the primary actions; below it a rounded
/// content sheet with the search field, filter chips, compact insight tiles,
/// and the document cards. Search is inline (`onChanged`), and the document
/// type picker plus sort order live in bottom sheets behind the filter and
/// sort buttons.
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
        return Icons.event_busy_rounded;
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

  @override
  void initState() {
    super.initState();
    if (DocumentScannerService.instance.isInitialized) {
      _items = DocumentScannerService.instance.activeItems;
      _loading = false;
    }
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
    // Include expired documents so the "Expired" filter and the header can
    // show documents that already lapsed.
    final items = await DocumentScannerService().getAllItems(
      includeExpired: true,
    );
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
      if (_typeFilter != null && i.docType.key != _typeFilter!.key) {
        return false;
      }
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
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
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

  /// Nearest upcoming document — shown in the insights tiles.
  ExpiryItem? get _nextDue {
    final now = DateTime.now();
    final active =
        _items.where((i) => i.isActive && i.expiresAt.isAfter(now)).toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return active.isEmpty ? null : active.first;
  }

  double get _totalUpcomingFees {
    final now = DateTime.now();
    return _items
        .where(
          (i) =>
              i.isActive && i.expiresAt.isAfter(now) && (i.renewalFee ?? 0) > 0,
        )
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
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filtered;

    return Scaffold(
      // Ink backdrop behind the hero; the content sheet covers the rest.
      // Same backdrop colors as the redesigned Home tab.
      backgroundColor: isDark
          ? WazyColors.obsidian
          : WazyColors.ink,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
                color: theme.colorScheme.secondary,
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeroHeader(theme, urgency, filtered.length),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: _loading
                            ? SizedBox(
                                height: 320,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                            const SizedBox(height: 16),
                            // Inline search field, styled like the tiles.
                            _buildSearchField(theme),
                            const SizedBox(height: 12),
                            // Status filter chips.
                            _buildStatusChips(theme, urgency),
                            // Active-filter summary: visible only when it
                            // matters, so the sheet never shows a phantom gap.
                            if (_hasActiveFilters) ...[
                              const SizedBox(height: 8),
                              _buildActiveFiltersRow(theme),
                            ],
                            const SizedBox(height: 16),
                            // Insight tiles: what the list means at a glance.
                            _buildInsights(theme, urgency, filtered.length),
                            const SizedBox(height: 16),
                            // Document list.
                            _buildDocumentList(theme, filtered),
                            // Keep the last card scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height:
                                  8 +
                                  MediaQuery.of(context).padding.bottom +
                                  80,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // White filler: extends the sheet across the rest of the
                    // viewport when content is short, and into overscroll —
                    // the navy backdrop never peeks out below the content,
                    // behind the floating nav pill. Kept empty: a
                    // fill-remaining sliver queries the child's intrinsics
                    // during overscroll, which a shrinkWrap list can't do.
                    SliverFillRemaining(
                      hasScrollBody: false,
                      fillOverscroll: true,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Hero header: greeting, live status line, action pills
  // ------------------------------------------------------------------

  Widget _buildHeroHeader(
    ThemeData theme,
    UrgencySnapshot urgency,
    int visibleCount,
  ) {
    final pending = urgency.pendingActions.length;
    final expired = _items.where((i) => i.isActive && i.isExpired).length;

    // Compact hero (deliberately smaller than Home's): one status line that
    // doubles as the filter feedback — "shown" only appears while filters
    // narrow the list.
    final statusPart = expired > 0
        ? '$expired expired'
        : pending > 0
        ? '$pending need attention'
        : 'All on track';
    final scopePart = _hasActiveFilters
        ? '$visibleCount of ${_items.length} shown'
        : '${_items.length} tracked';
    final subtitle = '$statusPart · $scopePart';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Documents',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Quick Add with Natural Language (AI-assisted add).
              _HeroIconButton(
                icon: Icons.bolt_rounded,
                tooltip: 'Quick Add with Natural Language',
                onTap: () async {
                  final created = await NaturalLanguageAddDialog.show(context);
                  if (created != null) _loadData();
                },
              ),
              const SizedBox(width: 8),
              _HeroIconButton(
                icon: Icons.saved_search_rounded,
                tooltip: 'Search all documents',
                onTap: () => context.push('/search'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Single-line live status + scope.
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // Action pills: filter + sort, mirroring Home's Record/Budget row.
          Row(
            children: [
              _HeroActionPill(
                icon: Icons.filter_alt_rounded,
                label: 'Filter',
                outlined: true,
                onTap: _showTypeFilterSheet,
              ),
              const SizedBox(width: 10),
              _HeroActionPill(
                icon: Icons.sort_rounded,
                label: 'Sort',
                outlined: true,
                onTap: _showSortSheet,
              ),
              const Spacer(),
              _HeroActionPill(
                icon: Icons.add_rounded,
                label: 'Add',
                filled: true,
                onTap: _openScanner,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Open the scan flow after enforcing the free-tier document limit.
  Future<void> _openScanner() async {
    if (!await enforceDocumentLimit(context)) return;
    if (mounted) await context.push('/scan');
  }

  // ------------------------------------------------------------------
  // Content sheet: search, chips, insights, list
  // ------------------------------------------------------------------

  Widget _buildSearchField(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(
          color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search documents…',
          hintStyle: TextStyle(
            color: isDark ? WazyColors.textMuted : WazyColors.textMutedLight,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark
                ? WazyColors.textSecondary
                : WazyColors.textSecondaryLight,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark
                        ? WazyColors.textSecondary
                        : WazyColors.textSecondaryLight,
                  ),
                  onPressed: () => setState(() => _query = ''),
                ),
          filled: true,
          fillColor: isDark
              ? WazyColors.slate.withOpacity(0.55)
              : WazyColors.cloud,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WazyRadius.field),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChips(ThemeData theme, UrgencySnapshot urgency) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statusChip(
            theme,
            'All',
            _DocFilter.all,
            _items.where((i) => i.isActive || i.isExpired).length,
          ),
          _statusChip(
            theme,
            'Critical',
            _DocFilter.critical,
            urgency.criticalCount,
          ),
          _statusChip(
            theme,
            '≤30 days',
            _DocFilter.upcoming,
            urgency.highCount,
          ),
          _statusChip(
            theme,
            'Later',
            _DocFilter.later,
            urgency.mediumCount + urgency.lowCount,
          ),
          _statusChip(
            theme,
            'Expired',
            _DocFilter.expired,
            _items.where((i) => !i.isActive && i.isExpired).length,
          ),
        ],
      ),
    );
  }

  /// One-line summary of the active filters, with a clear action.
  Widget _buildActiveFiltersRow(ThemeData theme) {
    final parts = <String>[
      if (_query.isNotEmpty) '"${_query.trim()}"',
      if (_typeFilter != null) _typeFilter!.displayName,
      if (_filter != _DocFilter.all)
        switch (_filter) {
          _DocFilter.all => '',
          _DocFilter.critical => 'Critical',
          _DocFilter.upcoming => '≤30 days',
          _DocFilter.later => 'Later',
          _DocFilter.expired => 'Expired',
        },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered: ${parts.where((p) => p.isNotEmpty).join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _clearFilters,
            child: Text(
              'Clear',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Insights — two tiles, mirroring Home's categories grid styling
  // ------------------------------------------------------------------

  Widget _buildInsights(
    ThemeData theme,
    UrgencySnapshot urgency,
    int visibleCount,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final tileBg = isDark
        ? WazyColors.slate.withOpacity(0.5)
        : Colors.white;
    final pending = urgency.pendingActions.length;
    final nextDue = _nextDue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _insightTile(
              theme,
              tileBg: tileBg,
              icon: Icons.hourglass_top_rounded,
              label: 'Next due',
              value: nextDue == null
                  ? '—'
                  : '${nextDue.displayName} · ${nextDue.daysRemaining}d',
              iconColor: WazyColors.orange,
              tint: WazyColors.orangeTint,
              onDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _insightTile(
              theme,
              tileBg: tileBg,
              icon: Icons.payments_rounded,
              label: 'Upcoming fees',
              value: _totalUpcomingFees > 0
                  ? MoneyFormat.aed(_totalUpcomingFees)
                  : '—',
              iconColor: WazyColors.teal,
              tint: WazyColors.tealTint,
              onDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightTile(
    ThemeData theme, {
    required Color tileBg,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Color? tint,
    bool onDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(WazyRadius.card),
      ),
      child: Row(
        children: [
          BentoIconTile(
            icon: icon,
            color: iconColor,
            tint: onDark ? tint?.withOpacity(0.16) : tint,
            size: 36,
            iconSize: 17,
            radius: 11,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Document list — compact cards, tinted left accent by urgency
  // ------------------------------------------------------------------

  Widget _buildDocumentList(ThemeData theme, List<ExpiryItem> filtered) {
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEmptyState(theme),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final item in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DocumentCard(
                item: item,
                onTap: () async {
                  await context.push('/document/${item.id}');
                  await _loadData();
                },
                onAction: () => _showActionSheet(context, item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(
            scene: _hasActiveFilters
                ? EmptyStateScene.search
                : EmptyStateScene.document,
            size: 104,
          ),
          const SizedBox(height: 12),
          Text(
            _hasActiveFilters ? 'No documents match' : 'Nothing tracked yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasActiveFilters
                ? 'Try a different filter or clear the search.'
                : 'Scan a trade licence, visa or Ejari to start tracking its expiry.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!_hasActiveFilters)
            FilledButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.add_rounded, size: 18),
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
  // Filter & sort bottom sheets
  // ------------------------------------------------------------------

  void _showTypeFilterSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
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
                child: Text(
                  'Document type',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.apps_rounded),
                      title: const Text('All types'),
                      trailing: _typeFilter == null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, '__all__'),
                    ),
                    for (final t
                        in DocumentTypeRegistry.instance.typesForPicker)
                      ListTile(
                        leading: Icon(t.icon, color: t.primaryColor),
                        title: Text(t.displayName),
                        trailing: _typeFilter?.key == t.key
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        onTap: () => Navigator.pop(sheetContext, t.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((value) {
      if (value == null || !mounted) return;
      setState(() {
        _typeFilter = value == '__all__'
            ? null
            : DocumentTypeRegistry.instance.typesForPicker
                  .where((t) => t.key == value)
                  .firstOrNull;
      });
    });
  }

  void _showSortSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet<_DocSort>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
              child: Text(
                'Sort by',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            for (final s in _DocSort.values)
              ListTile(
                leading: Icon(
                  s.icon,
                  color: _sort == s
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(s.label),
                trailing: _sort == s
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, s),
              ),
          ],
        ),
      ),
    ).then((value) {
      if (value is _DocSort && mounted) setState(() => _sort = value);
    });
  }

  // ------------------------------------------------------------------
  // Status chips
  // ------------------------------------------------------------------

  Widget _statusChip(
    ThemeData theme,
    String label,
    _DocFilter filter,
    int count,
  ) {
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
                : (isDark
                      ? WazyColors.textSecondary
                      : WazyColors.textPrimaryLight),
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
              : (isDark
                    ? WazyColors.slateLight.withOpacity(0.3)
                    : WazyColors.fog),
        ),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
              leading: const Icon(
                Icons.event_available_rounded,
                color: Colors.green,
              ),
              title: const Text('Mark as renewed'),
              subtitle: const Text('Reset the expiry clock'),
              onTap: () => Navigator.pop(ctx, 'renewed'),
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_calendar_rounded,
                color: Colors.blue,
              ),
              title: const Text('Update expiry date'),
              subtitle: const Text('Correct or adjust the date'),
              onTap: () => Navigator.pop(ctx, 'date'),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_add_alt_rounded,
                color: Colors.indigo,
              ),
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
    // Ask for the new expiry (and an optional re-uploaded file) instead of
    // archiving the document — renewal keeps it tracked.
    final result = await showRenewDocumentDialog(context, item);
    if (result == null) return;

    try {
      await DocumentScannerService.instance.markAsRenewed(
        item.id,
        newExpiryDate: result.newExpiry,
        fee: result.fee,
        renewedBy: result.renewedBy,
        note: result.note,
      );

      // Persist the replacement file when the user re-uploaded one.
      if (result.replacementFile != null) {
        final storedPath = await saveRenewalReplacementFile(
          item,
          result.replacementFile!,
        );
        final refreshed = await DocumentScannerService.instance.getItemById(
          item.id,
        );
        if (refreshed != null) {
          await DocumentScannerService.instance.updateItem(
            refreshed.copyWith(
              fileName: result.replacementFile!.name,
              filePath: storedPath ?? refreshed.filePath,
              fileSize: result.replacementFile!.size,
            ),
          );
        }
      }

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.displayName} renewed — now expires ${ExpiryItem.formatDate(result.newExpiry)} ✓',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not renew: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Assigned to $name')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.displayName} deleted')));
  }
}

// ====================================================================
// Frosted hero widgets — same look as Home's
// ====================================================================

/// Frosted glass icon button used in the hero header.
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Outlined / filled action pill inside the hero header, mirroring Home's
/// Record/Budget pills.
class _HeroActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool outlined;
  final VoidCallback onTap;

  const _HeroActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(!(filled && outlined));
    final Color bg;
    final Color fg;
    final BorderSide side;
    if (filled) {
      bg = Colors.white;
      fg = WazyColors.ink;
      side = BorderSide.none;
    } else {
      bg = Colors.white.withOpacity(0.10);
      fg = Colors.white;
      side = BorderSide(color: Colors.white.withOpacity(0.22));
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: side,
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Detailed document card — compact, tinted accent, inline actions
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
      if (days <= 7) return WazyColors.danger;
      if (days <= 30) return WazyColors.warning;
      if (days <= 60) return WazyColors.caution;
      return WazyColors.safe;
    } else {
      if (days <= 7) return const Color(0xFFDC2626); // Dark red
      if (days <= 30) return const Color(0xFFD97706); // Dark amber
      if (days <= 60) return const Color(0xFFB45309); // Dark ochre
      return const Color(0xFF059669); // Dark emerald
    }
  }

  /// Accent used for the left edge tint. Expired documents keep the danger
  /// accent even when `daysRemaining` reaches other bands.
  Color _edgeAccent(bool isDark) =>
      item.daysRemaining < 0 ? WazyColors.danger : _accentColor(isDark);

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
    final accent = _edgeAccent(isDark);

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
          // IntrinsicHeight: the colored edge must stretch to the card's
          // height, but the card sits in an unbounded scroll context where
          // CrossAxisAlignment.stretch alone would force infinite height.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored urgency edge.
                Container(width: 4, color: accent.withOpacity(0.8)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row.
                        Row(
                          children: [
                            DepartmentLogo(item: item, size: 44),
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
                                      color: isDark
                                          ? WazyColors.textPrimary
                                          : WazyColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.docType.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? WazyColors.textMuted
                                          : WazyColors.textSecondaryLight,
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
                                    color: accent.withOpacity(
                                      isDark ? 0.15 : 0.10,
                                    ),
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
                        // Time-remaining progress bar.
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
                            color: isDark
                                ? WazyColors.textMuted
                                : WazyColors.textMutedLight,
                            fontSize: 10,
                          ),
                        ),
                        // Detail rows.
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
                                'Renewal fee ${DocumentCollectionService.instance.activeCurrency} ${item.renewalFee!.toStringAsFixed(0)}',
                              ),
                            _detail(
                              theme,
                              Icons.notifications_active_outlined,
                              _reminderText,
                            ),
                          ],
                        ),
                        // Renewal warning — expiry-aware fallback keeps this
                        // meaningful even when no warning was stored.
                        if (item.daysRemaining <= 30) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.effectiveRenewalWarning,
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Inline actions.
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onAction,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: isDark
                                      ? WazyColors.cyanSecondary
                                      : WazyColors.navyPrimary,
                                ),
                                label: Text(
                                  'Actions',
                                  style: TextStyle(
                                    color: isDark
                                        ? WazyColors.cyanSecondary
                                        : WazyColors.navyPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  side: BorderSide(
                                    color: isDark
                                        ? WazyColors.cyanSecondary.withOpacity(
                                            0.4,
                                          )
                                        : WazyColors.navyPrimary.withOpacity(
                                            0.3,
                                          ),
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
              ],
            ),
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
            color: isDark
                ? WazyColors.textSecondary
                : WazyColors.textPrimaryLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
