import 'package:flutter/material.dart';
import 'gcc_country.dart';

/// A named collection of expiry-tracked documents owned by the signed-in user.
///
/// Every user gets exactly one built-in [DocumentCollection.personal] collection
/// for their own documents (National ID, visa, vehicle registration, insurance,
/// subscriptions, ...), and may additionally create any number of company
/// collections across any GCC country (UAE, KSA, Kuwait, Qatar, Bahrain, Oman).
class DocumentCollection {
  /// Stable id of the built-in personal collection in local-only mode.
  /// In Supabase-backed mode the personal collection is a real row and uses
  /// its database uuid — see [DocumentCollectionService.isPersonal].
  static const String personalId = 'personal';

  final String id;
  final String name;

  /// ISO 2-letter country code for the GCC country this collection belongs to
  /// ('AE', 'SA', 'KW', 'QA', 'BH', 'OM'). Defaults to 'AE'.
  final String countryCode;

  /// True for the built-in personal collection. It always exists and cannot
  /// be renamed or deleted.
  final bool isPersonal;

  const DocumentCollection({
    required this.id,
    required this.name,
    this.countryCode = 'AE',
    this.isPersonal = false,
  });

  /// The built-in personal collection (local-only mode fallback).
  const DocumentCollection.personal({String countryCode = 'AE'})
      : this(
          id: personalId,
          name: 'Personal',
          countryCode: countryCode,
          isPersonal: true,
        );

  /// Helper to get the strongly typed GCC country enum.
  GccCountry get country => GccCountry.fromCode(countryCode);

  factory DocumentCollection.fromJson(Map<String, dynamic> json) {
    return DocumentCollection(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Collection',
      countryCode: (json['countryCode'] ?? json['country_code']) as String? ?? 'AE',
      isPersonal: json['isPersonal'] ?? json['is_personal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'countryCode': countryCode,
      'country_code': countryCode,
      'isPersonal': isPersonal,
    };
  }

  /// Icon representing this collection type (personal vs company).
  IconData get icon =>
      isPersonal ? Icons.person_rounded : Icons.business_rounded;

  /// Short subtitle shown under the collection name.
  String get subtitle =>
      '${country.displayName} (${country.currency}) • ${isPersonal ? "Personal" : "Company"}';

  @override
  bool operator ==(Object other) =>
      other is DocumentCollection && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DocumentCollection($id, $name, $countryCode)';
}

