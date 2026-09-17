import 'package:intl/intl.dart';

/// Represents a single historical renewal event for a document.
class RenewalRecord {
  final String id;
  final DateTime renewedAt;
  final DateTime previousExpiryDate;
  final DateTime newExpiryDate;
  final double? fee;
  final String? renewedBy;
  final String? note;

  const RenewalRecord({
    required this.id,
    required this.renewedAt,
    required this.previousExpiryDate,
    required this.newExpiryDate,
    this.fee,
    this.renewedBy,
    this.note,
  });

  factory RenewalRecord.fromJson(Map<String, dynamic> json) {
    return RenewalRecord(
      id: json['id'] as String,
      renewedAt: DateTime.parse(json['renewedAt'] as String),
      previousExpiryDate: DateTime.parse(json['previousExpiryDate'] as String),
      newExpiryDate: DateTime.parse(json['newExpiryDate'] as String),
      fee: (json['fee'] as num?)?.toDouble(),
      renewedBy: json['renewedBy'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'renewedAt': renewedAt.toIso8601String(),
      'previousExpiryDate': previousExpiryDate.toIso8601String(),
      'newExpiryDate': newExpiryDate.toIso8601String(),
      'fee': fee,
      'renewedBy': renewedBy,
      'note': note,
    };
  }

  String get formattedRenewedAt => DateFormat('dd MMM yyyy').format(renewedAt);
  String get formattedPreviousExpiry => DateFormat('dd MMM yyyy').format(previousExpiryDate);
  String get formattedNewExpiry => DateFormat('dd MMM yyyy').format(newExpiryDate);
}
