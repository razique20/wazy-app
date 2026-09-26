import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import 'collection_service.dart';

/// Which lifecycle states the expiry list shows.
enum ExpiryStatusFilter {
  /// Active documents only (default).
  active,

  /// Only documents past their expiry date.
  expired,

  /// Both active and expired.
  all,
}

/// Sort options for the expiry list.
enum ExpirySortMode {
  dueDate('Due date'),
  dueDateDesc('Due date (latest first)'),
  name('Name (A–Z)'),
  urgency('Urgency (soonest first)'),
  fee('Renewal fee (high → low)');

  final String label;
  const ExpirySortMode(this.label);
}

/// Immutable bundle of every active filter for the expiry list, plus the
/// [apply] function that runs it. Pure logic — kept out of the widget so the
/// filtering rules stay unit-testable without pumpWidget.
///
/// All predicates are AND-combined; a null/unset filter means "no
/// restriction" for that dimension.
class ExpiryFilterSpec {
  /// Restrict to one document type, or null for all types.
  final DocumentTypeMeta? docType;

  /// Restrict to one urgency tier, or null for all.
  final UrgencyLevel? urgency;

  /// Non-zero restricts to documents with this reminder/escalation status
  /// (see [_urgencyStatusChips] in the expiry-list screen).
  final int reminderStatus;

  /// Restrict to one collection, or null for all collections.
  final String? collectionId;

  /// Inclusive days-remaining window.
  final int daysMin;
  final int daysMax;

  /// Which lifecycle states to include (active / expired / both).
  final ExpiryStatusFilter status;

  /// Free-text needle matched against the same fields as global search.
  final String query;

  final ExpirySortMode sortMode;

  const ExpiryFilterSpec({
    this.docType,
    this.urgency,
    this.reminderStatus = 0,
    this.collectionId,
    this.daysMin = 0,
    this.daysMax = 730,
    this.status = ExpiryStatusFilter.active,
    this.query = '',
    this.sortMode = ExpirySortMode.dueDate,
  });

  /// The default filter — everything active, sorted by soonest expiry.
  static const ExpiryFilterSpec all = ExpiryFilterSpec();

  /// Sentinel for "leave this field unchanged" in [copyWith], so that
  /// clearing a filter (`docType: null`) is distinguishable from not
  /// touching it.
  static const Object _unset = Object();

  /// True when any dimension restricts the list (used to show a
  /// "clear filters" affordance).
  bool get hasRestrictions =>
      docType != null ||
      urgency != null ||
      reminderStatus != 0 ||
      collectionId != null ||
      daysMin > 0 ||
      daysMax < 730 ||
      status != ExpiryStatusFilter.active ||
      query.trim().isNotEmpty;

  /// Copy with per-dimension overrides. Pass an explicit `null` to clear a
  /// dimension; omit it (the [_unset] sentinel) to keep the current value.
  // ignore: avoid_annotating_with_dynamic
  ExpiryFilterSpec copyWith({
    Object? docType = _unset,
    Object? urgency = _unset,
    int? reminderStatus,
    Object? collectionId = _unset,
    int? daysMin,
    int? daysMax,
    ExpiryStatusFilter? status,
    String? query,
    ExpirySortMode? sortMode,
  }) {
    return ExpiryFilterSpec(
      docType: identical(docType, _unset)
          ? this.docType
          : docType as DocumentTypeMeta?,
      urgency: identical(urgency, _unset)
          ? this.urgency
          : urgency as UrgencyLevel?,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      collectionId: identical(collectionId, _unset)
          ? this.collectionId
          : collectionId as String?,
      daysMin: daysMin ?? this.daysMin,
      daysMax: daysMax ?? this.daysMax,
      status: status ?? this.status,
      query: query ?? this.query,
      sortMode: sortMode ?? this.sortMode,
    );
  }

  /// Run the filter chain over [items] and return a new sorted list.
  ///
  /// Inactive non-expired records (renewed/offboarded) are never listed.
  /// Expired documents only appear per [ExpiryStatusFilter], and are exempt
  /// from the days-remaining window (theirs is negative).
  static List<ExpiryItem> apply(
    List<ExpiryItem> items,
    ExpiryFilterSpec spec,
  ) {
    Iterable<ExpiryItem> filtered = items.where((i) {
      if (!i.isActive && !i.isExpired) return false;
      if (i.isExpired) return spec.status != ExpiryStatusFilter.active;
      return spec.status != ExpiryStatusFilter.expired;
    });

    final q = spec.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      bool matches(ExpiryItem i) => DocumentScannerSearch.matchesQuery(i, q);
      filtered = filtered.where(matches);
    }

    if (spec.docType != null) {
      final key = spec.docType!.key;
      filtered = filtered.where((i) => i.docType.key == key);
    }

    if (spec.urgency != null) {
      final priority = spec.urgency!.priority;
      filtered = filtered.where((i) => i.urgency.priority == priority);
    }

    if (spec.reminderStatus > 0) {
      filtered = filtered.where((i) => i.reminderStatus == spec.reminderStatus);
    }

    if (spec.collectionId != null) {
      final cid = spec.collectionId;
      filtered = filtered.where((i) => i.collectionId == cid);
    }

    final result = filtered
        .where((i) =>
            i.isExpired ||
            (i.daysRemaining >= spec.daysMin && i.daysRemaining <= spec.daysMax))
        .toList();

    void sort(List<ExpiryItem> list) {
      switch (spec.sortMode) {
        case ExpirySortMode.dueDate:
          list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
        case ExpirySortMode.dueDateDesc:
          list.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
        case ExpirySortMode.name:
          list.sort((a, b) =>
              a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        case ExpirySortMode.urgency:
          list.sort((a, b) {
            final byDays = a.daysRemaining.compareTo(b.daysRemaining);
            if (byDays != 0) return byDays;
            return a.expiresAt.compareTo(b.expiresAt);
          });
        case ExpirySortMode.fee:
          list.sort((a, b) {
            final byFee = (b.renewalFee ?? 0).compareTo(a.renewalFee ?? 0);
            if (byFee != 0) return byFee;
            return a.expiresAt.compareTo(b.expiresAt);
          });
      }
    }

    sort(result);
    return result;
  }
}

/// Shared, testable text-match rules for document search. Used by global
/// search ([DocumentScannerService.search]) and the expiry-list query filter.
class DocumentScannerSearch {
  DocumentScannerSearch._();

  /// Case-insensitive substring match of [query] against the searchable
  /// text of [item]: display name, description/notes, location, assignee,
  /// renewal warning, type name and file name.
  static bool matchesQuery(ExpiryItem item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String? field) => field != null && field.toLowerCase().contains(q);
    return has(item.displayName) ||
        has(item.description) ||
        has(item.location) ||
        has(item.assignedTo) ||
        has(item.renewalWarning) ||
        has(item.docType.displayName) ||
        has(item.fileName);
  }
}

/// Expiry-report export: CSV string builder and PDF generator.
///
/// Both formats share [rows] so accountants get identical columns whether
/// they open the CSV in Excel or the PDF on paper. Pure logic — file saving
/// (FilePicker.saveFile / printing.sharePdf) happens in the UI layer.
class ExpiryReport {
  ExpiryReport._();

  static List<String> get header => [
    'Document',
    'Type',
    'Expiry date',
    'Days remaining',
    'Status',
    'Assigned to',
    'Renewal fee (${DocumentCollectionService.instance.activeCurrency})',
    'Notes',
  ];

  /// One row per document, same order as [header]. Text is sanitised to
  /// Latin-1 (WinAnsi) because the built-in PDF fonts cannot render other
  /// code points — e.g. 'AED 1,500 — renew' becomes 'AED 1,500 - renew'.
  static List<List<String>> rows(List<ExpiryItem> items) {
    final sorted = [...items]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    String clean(String value) => value
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('·', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('…', '...');
    return sorted.map((i) {
      final status = i.isExpired
          ? 'Expired'
          : i.daysRemaining <= 7
              ? 'Critical'
              : i.daysRemaining <= 30
                  ? 'Due soon'
                  : 'On track';
      return [
        clean(i.displayName),
        clean(i.docType.displayName),
        ExpiryItem.formatDate(i.expiresAt),
        '${i.daysRemaining}',
        status,
        clean(i.assignedTo ?? ''),
        i.renewalFee?.toStringAsFixed(2) ?? '',
        clean(i.description ?? i.renewalWarning ?? ''),
      ].map((cell) => cell.replaceAll(RegExp(r'[^\x20-\x7E\n]'), '?')).toList();
    }).toList();
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// RFC-4180-ish CSV of the expiry report.
  static String toCsv(List<ExpiryItem> items) {
    final buffer = StringBuffer(header.join(','));
    buffer.write('\n');
    for (final row in rows(items)) {
      buffer.write(row.map(_csvEscape).join(','));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// A4 landscape PDF with a simple grid table. Caller is responsible for
  /// saving/sharing the returned bytes.
  static Future<List<int>> toPdf(List<ExpiryItem> items) async {
    final pdf = pw.Document();
    final data = rows(items);
    // Built-in Helvetica (Type1) keeps the PDF dependency-light. It is
    // WinAnsi-encoded, so report strings must stay ASCII — [rows] sanitises
    // below.
    final bold = pw.Font.helveticaBold();
    final normal = pw.Font.helvetica();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Finavig - Expiry report',
              style: pw.TextStyle(fontSize: 18, font: bold),
            ),
            pw.Text(
              'Generated ${ExpiryItem.formatDate(DateTime.now())} - ${data.length} documents',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: normal),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: header,
              data: data,
              headerStyle: pw.TextStyle(fontSize: 9, font: bold),
              cellStyle: pw.TextStyle(fontSize: 8, font: normal),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }
}
