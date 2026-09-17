import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/finance.dart';

/// Severity of a detected price spike anomaly.
enum AnomalySeverity { moderate, high, critical }

extension AnomalySeverityX on AnomalySeverity {
  String get label {
    switch (this) {
      case AnomalySeverity.moderate:
        return 'Moderate Spike';
      case AnomalySeverity.high:
        return 'High Spike';
      case AnomalySeverity.critical:
        return 'Critical Spike';
    }
  }

  String get badgeText {
    switch (this) {
      case AnomalySeverity.moderate:
        return '+20% Spike';
      case AnomalySeverity.high:
        return '+35% Spike';
      case AnomalySeverity.critical:
        return '+50% Spike';
    }
  }
}

/// Details of a detected bill price spike anomaly.
class BillAnomaly {
  final FinanceTransaction transaction;
  final double historicalAverage;
  final double percentIncrease;
  final double standardDeviation;
  final AnomalySeverity severity;
  final String message;

  const BillAnomaly({
    required this.transaction,
    required this.historicalAverage,
    required this.percentIncrease,
    required this.standardDeviation,
    required this.severity,
    required this.message,
  });

  @override
  String toString() =>
      'BillAnomaly("${transaction.title}", +${percentIncrease.toStringAsFixed(1)}%, severity: ${severity.name})';
}

/// Statistical Anomaly Detection Engine for Wazy expenses & recurring bills.
class AnomalyDetectionService {
  static final AnomalyDetectionService instance = AnomalyDetectionService._();
  AnomalyDetectionService._();

  /// Evaluates a single transaction against historical records to check for a price spike anomaly.
  BillAnomaly? evaluateTransaction(
    FinanceTransaction candidate,
    List<FinanceTransaction> history, {
    int historyDays = 120,
  }) {
    if (candidate.kind != FinanceKind.expense || candidate.amount <= 0) {
      return null;
    }

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: historyDays));

    // 1. Find matching historical expense records
    final matches = <FinanceTransaction>[];
    final candTitleNorm = _normalizeTitle(candidate.title);

    for (final tx in history) {
      if (tx.id == candidate.id) continue;
      if (tx.collectionId != candidate.collectionId) continue;
      if (tx.kind != FinanceKind.expense) continue;
      if (tx.amount <= 0) continue;
      if (tx.occurredAt.isBefore(cutoff)) continue;

      final isDocMatch = candidate.documentId != null &&
          candidate.documentId == tx.documentId;
      final isTitleMatch = candTitleNorm.isNotEmpty &&
          _normalizeTitle(tx.title) == candTitleNorm;

      if (isDocMatch || isTitleMatch) {
        matches.add(tx);
      }
    }

    // Fallback: If no direct title match, match by category if at least 4 entries exist
    if (matches.length < 2) {
      matches.clear();
      for (final tx in history) {
        if (tx.id == candidate.id) continue;
        if (tx.collectionId != candidate.collectionId) continue;
        if (tx.kind != FinanceKind.expense || tx.amount <= 0) continue;
        if (tx.occurredAt.isBefore(cutoff)) continue;
        if (tx.category == candidate.category) {
          matches.add(tx);
        }
      }
    }

    // Need at least 2 historical data points to calculate mean & std dev
    if (matches.length < 2) return null;

    // 2. Compute mean (moving average)
    final sum = matches.fold(0.0, (acc, t) => acc + t.amount);
    final mean = sum / matches.length;

    if (mean <= 0) return null;

    // 3. Compute sample standard deviation
    double varianceSum = 0;
    for (final t in matches) {
      varianceSum += math.pow(t.amount - mean, 2);
    }
    final stdDev = math.sqrt(varianceSum / (matches.length - 1));

    // 4. Anomaly criteria: Amount > mean + 1.25 * stdDev AND at least 20% higher than mean
    final percentIncrease = ((candidate.amount - mean) / mean) * 100;

    if (candidate.amount > (mean + (1.25 * stdDev)) && percentIncrease >= 20.0) {
      final severity = _determineSeverity(percentIncrease);
      final title = candidate.title.trim();
      final msg =
          '$title bill (${MoneyFormat.aed(candidate.amount)}) is +${percentIncrease.toStringAsFixed(0)}% higher than your average (${MoneyFormat.aed(mean)}).';

      return BillAnomaly(
        transaction: candidate,
        historicalAverage: mean,
        percentIncrease: percentIncrease,
        standardDeviation: stdDev,
        severity: severity,
        message: msg,
      );
    }

    return null;
  }

  /// Scans all transactions in recent days (default 30 days) for bill spike anomalies.
  List<BillAnomaly> detectRecentAnomalies(
    List<FinanceTransaction> transactions, {
    int recentDays = 30,
  }) {
    final now = DateTime.now();
    final recentCutoff = now.subtract(Duration(days: recentDays));

    final anomalies = <BillAnomaly>[];
    for (final tx in transactions) {
      if (tx.kind != FinanceKind.expense) continue;
      if (tx.occurredAt.isBefore(recentCutoff)) continue;

      final anomaly = evaluateTransaction(tx, transactions);
      if (anomaly != null) {
        anomalies.add(anomaly);
      }
    }

    // Sort by highest percent increase first
    anomalies.sort((a, b) => b.percentIncrease.compareTo(a.percentIncrease));
    return anomalies;
  }

  AnomalySeverity _determineSeverity(double percentIncrease) {
    if (percentIncrease >= 50.0) return AnomalySeverity.critical;
    if (percentIncrease >= 35.0) return AnomalySeverity.high;
    return AnomalySeverity.moderate;
  }

  String _normalizeTitle(String title) {
    return title.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
