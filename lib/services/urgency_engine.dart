import '../models/expiry_item.dart';

class UrgencySnapshot {
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final List<ExpiryItem> criticalItems;
  final List<ExpiryItem> highItems;
  final List<ExpiryItem> mediumItems;
  final List<ExpiryItem> lowItems;
  final List<ExpiryItem> alert7Days;
  final List<ExpiryItem> alert30Days;
  final List<ExpiryItem> alert60Days;
  final List<ExpiryItem> alert90Days;
  final List<ExpiryItem> pendingActions;
  final String summary;

  const UrgencySnapshot({
    this.criticalCount = 0,
    this.highCount = 0,
    this.mediumCount = 0,
    this.lowCount = 0,
    this.criticalItems = const [],
    this.highItems = const [],
    this.mediumItems = const [],
    this.lowItems = const [],
    this.alert7Days = const [],
    this.alert30Days = const [],
    this.alert60Days = const [],
    this.alert90Days = const [],
    this.pendingActions = const [],
    this.summary = '',
  });

  bool get isEmpty => criticalCount == 0 && highCount == 0 && mediumCount == 0;
  bool get isNotEmpty => !isEmpty;
}

class UrgencyEngine {
  Future<void> init() async {
    // No local state to initialize
  }

  UrgencySnapshot compute(List<ExpiryItem> items) {
    if (items.isEmpty) {
      return const UrgencySnapshot(summary: 'No documents tracked yet');
    }

    var criticalCount = 0;
    var highCount = 0;
    var mediumCount = 0;
    var lowCount = 0;
    final criticalItems = <ExpiryItem>[];
    final highItems = <ExpiryItem>[];
    final mediumItems = <ExpiryItem>[];
    final lowItems = <ExpiryItem>[];
    final alert7Days = <ExpiryItem>[];
    final alert30Days = <ExpiryItem>[];
    final alert60Days = <ExpiryItem>[];
    final alert90Days = <ExpiryItem>[];
    final pendingActions = <ExpiryItem>[];

    for (final item in items) {
      if (!item.isActive) continue;

      final days = item.daysRemaining;

      if (days <= 7) {
        criticalCount++;
        criticalItems.add(item);
        alert7Days.add(item);
        pendingActions.add(item);
      } else if (days <= 30) {
        highCount++;
        highItems.add(item);
        alert30Days.add(item);
        pendingActions.add(item);
      } else if (days <= 60) {
        mediumCount++;
        mediumItems.add(item);
        alert60Days.add(item);
      } else if (days <= 90) {
        lowCount++;
        lowItems.add(item);
        alert90Days.add(item);
      } else {
        lowCount++;
        lowItems.add(item);
      }
    }

    final totalPending = criticalCount + highCount;
    final summary = totalPending > 0
        ? '$criticalCount critical, $highCount high priority renewals due'
        : 'All documents on track';

    return UrgencySnapshot(
      criticalCount: criticalCount,
      highCount: highCount,
      mediumCount: mediumCount,
      lowCount: lowCount,
      criticalItems: criticalItems,
      highItems: highItems,
      mediumItems: mediumItems,
      lowItems: lowItems,
      alert7Days: alert7Days,
      alert30Days: alert30Days,
      alert60Days: alert60Days,
      alert90Days: alert90Days,
      pendingActions: pendingActions,
      summary: summary,
    );
  }
}
