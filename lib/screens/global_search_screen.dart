import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/expiry_item.dart';
import '../services/document_scanner_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cards/document_list_tile.dart';
import '../widgets/indicators/empty_state_illustration.dart';

/// Global search across every collection: matches document name, record
/// numbers (notes/authority fields), assigned-to, file name and type name.
///
/// Debounced live results; results are grouped under a count header and tap
/// through to the document detail screen.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<ExpiryItem> _results = [];
  bool _searched = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _runSearch('');
    DocumentScannerService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    DocumentScannerService.instance.removeListener(_onServiceChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _runSearch(_controller.text);
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    final results = await DocumentScannerService.instance.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searched = query.trim().isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _runSearch,
            onChanged: (v) {
              // Debounce: cancel the previous pending search by simple delay
              // token comparison.
              final token = DateTime.now().microsecondsSinceEpoch;
              _lastToken = token;
              Future.delayed(const Duration(milliseconds: 250), () {
                if (mounted && _lastToken == token) _runSearch(v);
              });
            },
            decoration: InputDecoration(
              hintText: 'Search name, number, notes…',
              border: InputBorder.none,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _runSearch('');
                      },
                    ),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading && _results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmpty(theme)
              : _buildResults(theme),
    );
  }

  int _lastToken = 0;

  Widget _buildResults(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_results.length} result${_results.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = _results[index];
              return DocumentListTile(
                item: item,
                onTap: () => context.push('/document/${item.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyStateIllustration(
            scene: _searched
                ? EmptyStateScene.search
                : EmptyStateScene.document,
            size: 120,
          ),
          const SizedBox(height: 16),
          Text(
            _searched ? 'Nothing found' : 'Search all your documents',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searched
                ? 'Try a different name, number or note text.'
                : 'Names, record numbers, notes, assignees and file names\nare all searched across every collection.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
