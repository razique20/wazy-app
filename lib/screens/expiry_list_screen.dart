import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/subscription_tier.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/expiry_report.dart';
import '../services/urgency_engine.dart';
import '../widgets/indicators/empty_state_illustration.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/renew_document_dialog.dart';
import '../widgets/widgets.dart';

class ExpiryListScreen extends StatefulWidget {
  const ExpiryListScreen({super.key});

  @override
  State<ExpiryListScreen> createState() => _ExpiryListScreenState();
}

class _ExpiryListScreenState extends State<ExpiryListScreen> {
  /// Documents from every collection — the collection filter narrows these;
  /// loading only the active collection would make that filter a no-op.
  List<ExpiryItem> _allItems = [];
  List<ExpiryItem> _filteredItems = [];
  ExpiryFilterSpec _spec = ExpiryFilterSpec.all;

  bool _loading = true;

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
    setState(() => _loading = true);
    // Expired documents ride along in the cache; the status filter decides
    // whether they are shown (and the export honours the visible list).
    final items = await DocumentScannerService.instance.getAllItems(
      includeExpired: true,
    );
    if (mounted) {
      setState(() {
        _allItems = items;
        _filteredItems = ExpiryFilterSpec.apply(items, _spec);
        _loading = false;
      });
    }
  }

  /// Convenience for the filter-sheet widgets: returns a spec with one
  /// dimension changed and immediately re-applies it.
  void _updateSpec(ExpiryFilterSpec Function(ExpiryFilterSpec) mutate) {
    setState(() {
      _spec = mutate(_spec);
      _filteredItems = ExpiryFilterSpec.apply(_allItems, _spec);
    });
  }

  void _clearFilters() {
    _updateSpec((_) => ExpiryFilterSpec.all);
  }

  bool get _hasActiveFilters => _spec.hasRestrictions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_filteredItems);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Upcoming Expiries'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear filters'),
            ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _exportReport,
            tooltip: 'Export report (CSV / PDF)',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filter chips
          if (_hasActiveFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...(_spec.docType != null
                        ? [
                            Chip(
                              label: Text(_spec.docType!.displayName),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () =>
                                  _updateSpec((s) => s.copyWith(docType: null)),
                              backgroundColor: _spec.docType!.primaryColor
                                  .withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: _spec.docType!.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                    ...(_spec.urgency != null
                        ? [
                            Chip(
                              label: Text(_spec.urgency!.title),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () =>
                                  _updateSpec((s) => s.copyWith(urgency: null)),
                              backgroundColor: _spec.urgency!.color.withOpacity(
                                0.15,
                              ),
                              labelStyle: TextStyle(
                                color: _spec.urgency!.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                    ...(_spec.reminderStatus > 0
                        ? [
                            _urgencyStatusChips[_spec.reminderStatus] != null
                                ? Chip(
                                    label: Text(
                                      _urgencyStatusChips[_spec
                                          .reminderStatus]!,
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 16,
                                    ),
                                    onDeleted: () => _updateSpec(
                                      (s) => s.copyWith(reminderStatus: 0),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ]
                        : []),
                    ...(_spec.status != ExpiryStatusFilter.active
                        ? [
                            Chip(
                              label: Text(
                                _spec.status == ExpiryStatusFilter.expired
                                    ? 'Expired only'
                                    : 'Active + expired',
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _updateSpec(
                                (s) => s.copyWith(
                                  status: ExpiryStatusFilter.active,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                    ...(_spec.collectionId != null
                        ? [
                            Chip(
                              label: Text(_collectionName(_spec.collectionId!)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _updateSpec(
                                (s) => s.copyWith(collectionId: null),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                    ...(_spec.daysMin > 0 || _spec.daysMax < 730
                        ? [
                            Chip(
                              label: Text(
                                _spec.daysMin > 0 && _spec.daysMax < 730
                                    ? '${_spec.daysMin}–${_spec.daysMax} days'
                                    : _spec.daysMin > 0
                                    ? '${_spec.daysMin}+ days'
                                    : '≤ ${_spec.daysMax} days',
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _updateSpec(
                                (s) => s.copyWith(daysMin: 0, daysMax: 730),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                  ],
                ),
              ),
            ),

          // Urgency summary
          if (!urgency.isEmpty)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${urgency.criticalCount} critical, ${urgency.highCount} high priority',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            urgency.summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                ? _buildEmptyState(theme)
                : _buildList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyStateIllustration(
            scene: _hasActiveFilters
                ? EmptyStateScene.search
                : EmptyStateScene.document,
            size: 120,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters
                ? 'No documents match filters'
                : 'No upcoming expiries',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? 'Try clearing filters to see all documents'
                : 'Upload documents to start tracking their expiry dates.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_hasActiveFilters)
            ElevatedButton.icon(
              onPressed: () async {
                // Free plan document limit — paywall when the quota is full.
                if (await enforceDocumentLimit(context) && context.mounted) {
                  await context.push('/scan');
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Upload documents'),
            ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _filteredItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return DocumentListTile(
            item: item,
            onTap: () => context.push('/document/${item.id}'),
            onAction: () => _showActionSheet(context, item),
          );
        },
      ),
    );
  }

  void _showActionSheet(BuildContext context, ExpiryItem item) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysLeft = item.daysRemaining;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Actions for ${item.displayName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$daysLeft days left',
                      style: TextStyle(
                        color: daysLeft <= 7
                            ? Colors.red
                            : daysLeft <= 30
                            ? Colors.amber
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Actions
              ListTile(
                leading: const Icon(
                  Icons.alarm_add_rounded,
                  color: Colors.amber,
                ),
                title: const Text('Set reminder'),
                subtitle: const Text('90 / 60 / 30 day reminders'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setReminder(context, item);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.assignment_turned_in,
                  color: Colors.blue,
                ),
                title: const Text('Assign to team member'),
                subtitle: const Text('Notify responsible person'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAssignDialog(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: Colors.green),
                title: const Text('Update expiry date'),
                subtitle: const Text('Correct or adjust date'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDatePickerDialog(context, item);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.purple,
                ),
                title: const Text('Mark as renewed'),
                subtitle: const Text('Document has been renewed'),
                onTap: () {
                  Navigator.pop(ctx);
                  _markAsRenewed(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.teal),
                title: const Text('Download document'),
                subtitle: const Text('Save a copy locally'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading ${item.displayName}...'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAssignDialog(BuildContext context, ExpiryItem item) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final team = [
      'Ahmed Al Mansoori',
      'Sarah Khan',
      'Mohammed Hassan',
      'Priya Sharma',
      'Omar Ibrahim',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign to'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter team member name',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Quick select:'),
            const SizedBox(height: 8),
            ...team.map(
              (member) => ListTile(
                title: Text(member),
                onTap: () {
                  nameController.text = member;
                  Navigator.pop(ctx);
                  _assign(context, item, member);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(ctx);
                _assign(context, item, nameController.text);
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showDatePickerDialog(BuildContext context, ExpiryItem item) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    DateTime selectedDate = item.expiresAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Update expiry date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Select new expiry date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateExpiryDate(context, item, selectedDate);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Mutations — delegate to the shared DocumentScannerService (which
  // persists to Supabase and notifies listeners), then refresh local state.
  // ----------------------------------------------------------------

  Future<void> _setReminder(BuildContext context, ExpiryItem item) async {
    try {
      await DocumentScannerService.instance.setReminderStatus(item.id, 1);
      await _loadData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder set for ${item.displayName}')),
        );
      }
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _assign(
    BuildContext context,
    ExpiryItem item,
    String name,
  ) async {
    try {
      await DocumentScannerService.instance.assignTo(item.id, name);
      await _loadData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assigned "${item.displayName}" to $name')),
        );
      }
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _updateExpiryDate(
    BuildContext context,
    ExpiryItem item,
    DateTime date,
  ) async {
    try {
      await DocumentScannerService.instance.updateExpiryDate(item.id, date);
      await _loadData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.displayName} expiry updated to ${DateFormat("dd MMM yyyy").format(date)}',
            ),
          ),
        );
      }
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _markAsRenewed(BuildContext context, ExpiryItem item) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.displayName} renewed — now expires ${ExpiryItem.formatDate(result.newExpiry)} ✓',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(context, e);
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action failed: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Display name for a collection id, falling back to the raw id when the
  /// collection no longer exists.
  String _collectionName(String id) {
    for (final c in DocumentCollectionService.instance.collections) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  void _showFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // the filter list caps itself at 65% height
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Filter documents',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Scrollable + height-capped so the (long) filter list fits on
              // small screens instead of overflowing the sheet.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Document type filter
                      const Text(
                        'Document type',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All types'),
                            selected: _spec.docType == null,
                            onSelected: (_) {
                              _updateSpec((s) => s.copyWith(docType: null));
                              Navigator.pop(ctx);
                            },
                          ),
                          ...DocumentTypeRegistry.instance.typesForPicker.map(
                            (type) => FilterChip(
                              avatar: Icon(
                                type.icon,
                                size: 16,
                                color: type.primaryColor,
                              ),
                              label: Text(type.displayName),
                              selected: _spec.docType?.key == type.key,
                              onSelected: (_) {
                                _updateSpec((s) => s.copyWith(docType: type));
                                Navigator.pop(ctx);
                              },
                              selectedColor: type.primaryColor.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Urgency filter
                      const Text(
                        'Urgency level',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...UrgencyLevel.values.map(
                        (level) => FilterChip(
                          avatar: Icon(
                            level.icon,
                            size: 16,
                            color: level == UrgencyLevel.critical
                                ? Colors.red
                                : level.color,
                          ),
                          label: Text(level.title),
                          selected: _spec.urgency?.priority == level.priority,
                          onSelected: (_) {
                            _updateSpec((s) => s.copyWith(urgency: level));
                            Navigator.pop(ctx);
                          },
                          selectedColor: level.color.withOpacity(0.2),
                        ),
                      ),
                      const Divider(height: 24),
                      // Urgency status filter
                      const Text(
                        'Urgency status',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_urgencyStatusChips.length, (i) {
                        if (i == 0) return const SizedBox.shrink();
                        return FilterChip(
                          label: Text(_urgencyStatusChips[i] ?? ''),
                          selected: _spec.reminderStatus == i,
                          onSelected: (_) {
                            _updateSpec((s) => s.copyWith(reminderStatus: i));
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const Divider(height: 24),
                      // Lifecycle status filter
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in ExpiryStatusFilter.values)
                            FilterChip(
                              label: Text(
                                status == ExpiryStatusFilter.active
                                    ? 'Active'
                                    : status == ExpiryStatusFilter.expired
                                    ? 'Expired'
                                    : 'All',
                              ),
                              selected: _spec.status == status,
                              onSelected: (_) {
                                _updateSpec((s) => s.copyWith(status: status));
                                Navigator.pop(ctx);
                              },
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Collection filter
                      const Text(
                        'Collection',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All collections'),
                            selected: _spec.collectionId == null,
                            onSelected: (_) {
                              _updateSpec(
                                (s) => s.copyWith(collectionId: null),
                              );
                              Navigator.pop(ctx);
                            },
                          ),
                          ...DocumentCollectionService.instance.collections.map(
                            (c) {
                              final isLocked = EntitlementService.instance.isCollectionLocked(c);
                              final reqFeature = EntitlementService.instance.requiredFeatureForCollection(c);
                              return FilterChip(
                                avatar: Icon(
                                  isLocked ? Icons.lock_rounded : c.icon,
                                  size: 16,
                                  color: isLocked ? WazyColors.warning : null,
                                ),
                                label: Text(isLocked ? '${c.name} (Locked)' : c.name),
                                selected: _spec.collectionId == c.id,
                                onSelected: (_) {
                                  Navigator.pop(ctx);
                                  if (isLocked) {
                                    showUpgradeDialog(context, reqFeature);
                                  } else {
                                    _updateSpec(
                                      (s) => s.copyWith(collectionId: c.id),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Days-remaining range
                      const Text(
                        'Days remaining',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _daysRangePresets
                            .map(
                              (preset) => FilterChip(
                                label: Text(preset.label),
                                selected:
                                    _spec.daysMin == preset.min &&
                                    _spec.daysMax == preset.max,
                                onSelected: (_) {
                                  _updateSpec(
                                    (s) => s.copyWith(
                                      daysMin: preset.min,
                                      daysMax: preset.max,
                                    ),
                                  );
                                  Navigator.pop(ctx);
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const Divider(height: 24),
                      // Sort order
                      const Text(
                        'Sort by',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ExpirySortMode.values
                            .map(
                              (mode) => ChoiceChip(
                                label: Text(mode.label),
                                selected: _spec.sortMode == mode,
                                onSelected: (_) {
                                  _updateSpec(
                                    (s) => s.copyWith(sortMode: mode),
                                  );
                                  Navigator.pop(ctx);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // Export — CSV / PDF of the currently filtered list
  // ----------------------------------------------------------------

  Future<void> _exportReport() async {
    // Track 1 gate: PDF/CSV report export is a Plus feature.
    if (!EntitlementService.instance.allows(EntitlementFeature.reportExport)) {
      await showUpgradeDialog(context, EntitlementFeature.reportExport);
      return;
    }

    final exportItems = _filteredItems;
    if (exportItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to export')));
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('Export as CSV'),
              subtitle: const Text('Opens in Excel / Google Sheets'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              subtitle: const Text('Share or print a formatted report'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      final stamp = DateTime.now().toIso8601String().split('T').first;
      if (choice == 'csv') {
        final csv = ExpiryReport.toCsv(exportItems);
        final path = await FilePicker.platform.saveFile(
          fileName: 'wazy-expiry-report-$stamp.csv',
          bytes: Uint8List.fromList(csv.codeUnits),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path != null ? 'CSV saved to $path' : 'Export cancelled',
            ),
          ),
        );
      } else {
        final bytes = await ExpiryReport.toPdf(exportItems);
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: 'wazy-expiry-report-$stamp.pdf',
        );
      }
    } catch (_) {
      // saveFile/sharePdf unsupported here — fall back to clipboard for CSV.
      if (choice == 'csv' && mounted) {
        await Clipboard.setData(
          ClipboardData(text: ExpiryReport.toCsv(exportItems)),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate the PDF')),
        );
      }
    }
  }
}

// Urgency status mapping
const Map<int, String> _urgencyStatusChips = {
  1: 'Reminder sent (90 days)',
  2: 'Task assigned (60 days)',
  3: 'Escalation triggered (30 days)',
  4: 'WhatsApp sent (7 days)',
};

class _DaysRangePreset {
  final String label;
  final int min;
  final int max;
  const _DaysRangePreset(this.label, this.min, this.max);
}

const List<_DaysRangePreset> _daysRangePresets = [
  _DaysRangePreset('All', 0, 730),
  _DaysRangePreset('≤ 7 days', 0, 7),
  _DaysRangePreset('8–30 days', 8, 30),
  _DaysRangePreset('31–60 days', 31, 60),
  _DaysRangePreset('61–90 days', 61, 90),
  _DaysRangePreset('90+ days', 91, 730),
];
