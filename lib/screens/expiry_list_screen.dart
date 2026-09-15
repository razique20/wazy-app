import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../services/urgency_engine.dart';
import '../services/document_scanner_service.dart';
import '../widgets/widgets.dart';

class ExpiryListScreen extends StatefulWidget {
  const ExpiryListScreen({super.key});

  @override
  State<ExpiryListScreen> createState() => _ExpiryListScreenState();
}

class _ExpiryListScreenState extends State<ExpiryListScreen> {
  List<ExpiryItem> _allItems = [];
  List<ExpiryItem> _filteredItems = [];
  DocumentType? _docTypeFilter;
  UrgencyLevel? _urgencyFilter;
  int _urgencyStatusFilter = 0; // 0 = all, 1 = reminder, 2 = task, 3 = escalation, 4 = whatsapp

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final items = await DocumentScannerService().getAllItems();
    if (mounted) {
      setState(() {
        _allItems = items;
        _filteredItems = _applyFilters(items);
        _loading = false;
      });
    }
  }

  List<ExpiryItem> _applyFilters(List<ExpiryItem> items) {
    var filtered = items.where((item) => item.isActive).toList();

    if (_docTypeFilter != null) {
      filtered = filtered.where((item) => item.docType == _docTypeFilter).toList();
    }

    if (_urgencyFilter != null) {
      filtered = filtered.where((item) => item.urgency == _urgencyFilter).toList();
    }

    if (_urgencyStatusFilter > 0) {
      filtered = filtered.where((item) => item.reminderStatus == _urgencyStatusFilter).toList();
    }

    filtered.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return filtered;
  }

  void _onFilterChanged() {
    setState(() {
      _filteredItems = _applyFilters(_allItems);
    });
  }

  void _clearFilters() {
    setState(() {
      _docTypeFilter = null;
      _urgencyFilter = null;
      _urgencyStatusFilter = 0;
      _filteredItems = _allItems.where((item) => item.isActive).toList();
    });
  }

  bool get _hasActiveFilters =>
      _docTypeFilter != null || _urgencyFilter != null || _urgencyStatusFilter > 0;

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
                    ...(_docTypeFilter != null
                        ? [
                            Chip(
                              label: Text(_docTypeFilter!.displayName),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _docTypeFilter = null);
                                _onFilterChanged();
                              },
                              backgroundColor: _docTypeFilter!.primaryColor.withOpacity(0.15),
                              labelStyle: TextStyle(color: _docTypeFilter!.primaryColor),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                    ...(_urgencyFilter != null
                        ? [
                            Chip(
                              label: Text(_urgencyFilter!.title),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _urgencyFilter = null);
                                _onFilterChanged();
                              },
                              backgroundColor: _urgencyFilter!.color.withOpacity(0.15),
                              labelStyle: TextStyle(color: _urgencyFilter!.color),
                            ),
                            const SizedBox(width: 4),
                          ]
                        : []),
                    ...(_urgencyStatusFilter > 0
                        ? [
                            _urgencyStatusChips[_urgencyStatusFilter] != null
                                ? Chip(
                                    label: Text(_urgencyStatusChips[_urgencyStatusFilter]!),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () {
                                      setState(() => _urgencyStatusFilter = 0);
                                      _onFilterChanged();
                                    },
                                  )
                                : const SizedBox.shrink(),
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
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
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
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters ? 'No documents match filters' : 'No upcoming expiries',
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
              onPressed: () => context.push('/scan'),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        color: daysLeft <= 7 ? Colors.red : daysLeft <= 30 ? Colors.amber : theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Actions
              ListTile(
                leading: const Icon(Icons.notifications_active, color: Colors.amber),
                title: const Text('Set reminder'),
                subtitle: const Text('90 / 60 / 30 day reminders'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setReminder(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in, color: Colors.blue),
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
                leading: const Icon(Icons.file_upload, color: Colors.purple),
                title: const Text('Mark as renewed'),
                subtitle: const Text('Document has been renewed'),
                onTap: () {
                  Navigator.pop(ctx);
                  _markAsRenewed(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download, color: Colors.teal),
                title: const Text('Download document'),
                subtitle: const Text('Save a copy locally'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading ${item.displayName}...')),
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
    final team = ['Ahmed Al Mansoori', 'Sarah Khan', 'Mohammed Hassan', 'Priya Sharma', 'Omar Ibrahim'];

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
            ...team.map((member) => ListTile(
              title: Text(member),
              onTap: () {
                nameController.text = member;
                Navigator.pop(ctx);
                _assign(context, item, member);
              },
            )),
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

  Future<void> _assign(BuildContext context, ExpiryItem item, String name) async {
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
    try {
      await DocumentScannerService.instance.markAsRenewed(item.id);
      await _loadData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.displayName} marked as renewed ✓'),
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

  void _showFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Document type filter
                    const Text('Document type', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All types'),
                          selected: _docTypeFilter == null,
                          onSelected: (_) {
                            setState(() {
                              _docTypeFilter = null;
                              _onFilterChanged();
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                        ...DocumentType.values.map((type) => FilterChip(
                          avatar: Icon(type.icon, size: 16, color: type.primaryColor),
                          label: Text(type.displayName),
                          selected: _docTypeFilter == type,
                          onSelected: (_) {
                            setState(() {
                              _docTypeFilter = type;
                              _onFilterChanged();
                            });
                            Navigator.pop(ctx);
                          },
                          selectedColor: type.primaryColor.withOpacity(0.2),
                        )),
                      ],
                    ),
                    const Divider(height: 24),
                    // Urgency filter
                    const Text('Urgency level', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ...UrgencyLevel.values.map((level) => FilterChip(
                      avatar: Icon(
                        level.icon,
                        size: 16,
                        color: level == UrgencyLevel.critical ? Colors.red : level.color,
                      ),
                      label: Text(level.title),
                      selected: _urgencyFilter == level,
                      onSelected: (_) {
                        setState(() {
                          _urgencyFilter = level;
                          _onFilterChanged();
                        });
                        Navigator.pop(ctx);
                      },
                      selectedColor: level.color.withOpacity(0.2),
                    )),
                    const Divider(height: 24),
                    // Urgency status filter
                    const Text('Urgency status', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ...List.generate(_urgencyStatusChips.length, (i) {
                      if (i == 0) return const SizedBox.shrink();
                      return FilterChip(
                        label: Text(_urgencyStatusChips[i] ?? ''),
                        selected: _urgencyStatusFilter == i,
                        onSelected: (_) {
                          setState(() {
                            _urgencyStatusFilter = i;
                            _onFilterChanged();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Urgency status mapping
const Map<int, String> _urgencyStatusChips = {
  1: 'Reminder sent (90 days)',
  2: 'Task assigned (60 days)',
  3: 'Escalation triggered (30 days)',
  4: 'WhatsApp sent (7 days)',
};
