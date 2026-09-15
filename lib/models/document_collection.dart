import 'package:flutter/material.dart';

/// A named collection of expiry-tracked documents owned by the signed-in user.
///
/// This is a personal app: every user gets exactly one built-in
/// [DocumentCollection.personal] collection for their own documents
/// (Emirates ID, visa, vehicle registration, insurance, subscriptions, ...),
/// and may additionally create any number of company collections to keep
/// business documents (trade licence, ejari, labour cards, ...) separate.
class DocumentCollection {
  /// Stable id of the built-in personal collection in local-only mode.
  /// In Supabase-backed mode the personal collection is a real row and uses
  /// its database uuid — see [DocumentCollectionService.isPersonal].
  static const String personalId = 'personal';

  final String id;
  final String name;

  /// True for the built-in personal collection. It always exists and cannot
  /// be renamed or deleted.
  final bool isPersonal;

  const DocumentCollection({
    required this.id,
    required this.name,
    this.isPersonal = false,
  });

  /// The built-in personal collection (local-only mode fallback).
  const DocumentCollection.personal()
      : this(id: personalId, name: 'Personal', isPersonal: true);

  factory DocumentCollection.fromJson(Map<String, dynamic> json) {
    return DocumentCollection(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Collection',
      isPersonal: json['isPersonal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isPersonal': isPersonal,
    };
  }

  /// Icon representing this collection type (personal vs company).
  IconData get icon =>
      isPersonal ? Icons.person_rounded : Icons.business_rounded;

  /// Short subtitle shown under the collection name.
  String get subtitle =>
      isPersonal ? 'Personal documents' : 'Company collection';

  @override
  bool operator ==(Object other) =>
      other is DocumentCollection && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DocumentCollection($id, $name)';
}
