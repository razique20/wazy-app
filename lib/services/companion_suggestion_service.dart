import '../models/document_type.dart';

/// One document type suggested to the user after they add a related one.
class CompanionSuggestion {
  /// The suggested document type.
  final DocumentType type;

  /// Why this type is usually tracked together with the one just added.
  final String reason;

  /// Display name of the pool this suggestion comes from.
  final String poolName;

  const CompanionSuggestion({
    required this.type,
    required this.reason,
    required this.poolName,
  });

  DocumentTypeMeta get meta => DocumentTypeRegistry.instance.byEnum(type);
}

/// A named group of document types that are usually tracked together in the
/// UAE — e.g. a trade licence implies visas, Emirates IDs and labour cards.
class CompanionPool {
  final String name;

  /// Short description of what the pool represents.
  final String description;

  /// Member types, anchored on [members.first] (the type that typically gets
  /// added first and triggers suggestions for the rest).
  final List<DocumentType> members;

  /// Why each member belongs to this pool, keyed by type. Every member must
  /// have an entry.
  final Map<DocumentType, String> reasons;

  const CompanionPool({
    required this.name,
    required this.description,
    required this.members,
    required this.reasons,
  });
}

/// Registry of UAE companion pools and the engine that turns them into
/// suggestions for a just-added document.
class CompanionSuggestionService {
  CompanionSuggestionService._();

  static final CompanionSuggestionService instance =
      CompanionSuggestionService._();

  /// Maximum suggestions shown at once.
  static const int maxSuggestions = 6;

  /// The pools, ordered so the most common (company setup) comes first.
  static const List<CompanionPool> pools = [
    // --- Company setup: the classic UAE business bundle -------------------
    CompanionPool(
      name: 'Company Setup',
      description: 'What a business usually tracks alongside its Trade Licence',
      members: [
        DocumentType.tradeLicence,
        DocumentType.visa,
        DocumentType.emiratesId,
        DocumentType.labourDocuments,
        DocumentType.ejari,
      ],
      reasons: {
        DocumentType.tradeLicence:
            'The licence anchors the company — renewals of visa and labour documents depend on it',
        DocumentType.visa:
            'Staff residence visas are issued under the trade licence and expire with it',
        DocumentType.emiratesId:
            'Every visa holder needs a valid Emirates ID, renewed in the same cycle',
        DocumentType.labourDocuments:
            'MOHRE labour cards must stay valid for anyone working under the licence',
        DocumentType.ejari:
            'The company tenancy must stay registered — licence renewal requires valid Ejari',
      },
    ),

    // --- Vehicle ownership -------------------------------------------------
    CompanionPool(
      name: 'Vehicle Ownership',
      description: 'What drivers track alongside a vehicle registration',
      members: [
        DocumentType.vehicleRegistration,
        DocumentType.drivingLicence,
        DocumentType.insurance,
      ],
      reasons: {
        DocumentType.vehicleRegistration:
            'The Mulkiya proves ownership and must be renewed yearly',
        DocumentType.drivingLicence:
            'You cannot legally drive the registered vehicle without a valid licence',
        DocumentType.insurance:
            'Vehicle insurance must be valid before registration can be renewed',
      },
    ),

    // --- Residency: personal documents that move together ------------------
    CompanionPool(
      name: 'Residency Bundle',
      description: 'Personal documents that are issued and renewed together',
      members: [
        DocumentType.passport,
        DocumentType.visa,
        DocumentType.emiratesId,
      ],
      reasons: {
        DocumentType.passport:
            'Visa and Emirates ID applications require a valid passport with 6+ months',
        DocumentType.visa:
            'The residence visa is stamped in the passport and renews with it',
        DocumentType.emiratesId:
            'The Emirates ID is issued against the residence visa',
      },
    ),

    // --- Premises: tenancy that feeds the licence --------------------------
    CompanionPool(
      name: 'Premises & Tenancy',
      description: 'Documents that keep a physical business location compliant',
      members: [
        DocumentType.ejari,
        DocumentType.tradeLicence,
        DocumentType.permits,
      ],
      reasons: {
        DocumentType.ejari:
            'Registered tenancy is the base requirement for operating at the premises',
        DocumentType.tradeLicence:
            'Licence renewal is blocked when the premises Ejari has lapsed',
        DocumentType.permits:
            'Municipality/Civil Defence permits are tied to the registered premises',
      },
    ),

    // --- Digital assets -----------------------------------------------------
    CompanionPool(
      name: 'Digital Assets',
      description: 'Online assets that lapse quietly and take the business down',
      members: [
        DocumentType.domainNames,
        DocumentType.softwareSubscriptions,
      ],
      reasons: {
        DocumentType.domainNames:
            'Domains host the website and email — expiry takes everything offline',
        DocumentType.softwareSubscriptions:
            'Business tools suspend quickly; renewals are frequent (often monthly)',
      },
    ),
  ];

  /// Suggestions to show after the user added [added] while already tracking
  /// [trackedTypeKeys] (the doc-type keys of their active documents).
  ///
  /// Rules:
  /// - Every pool containing [added] contributes its members the user does
  ///   NOT track yet (never [added] itself).
  /// - A pool whose members are all already tracked contributes nothing
  ///   (it is "complete").
  /// - Results are de-duplicated (a type may appear in several pools) and
  ///   capped at [maxSuggestions], keeping first-seen pool order.
  List<CompanionSuggestion> suggestionsFor(
    DocumentType added,
    Set<String> trackedTypeKeys,
  ) {
    final seen = <DocumentType>{added};
    final result = <CompanionSuggestion>[];

    for (final pool in pools) {
      if (!pool.members.contains(added)) continue;
      for (final member in pool.members) {
        if (seen.contains(member)) continue;
        final key = member.name;
        if (trackedTypeKeys.contains(key)) continue;
        seen.add(member);
        result.add(
          CompanionSuggestion(
            type: member,
            reason: pool.reasons[member]!,
            poolName: pool.name,
          ),
        );
        if (result.length >= maxSuggestions) return result;
      }
    }
    return result;
  }

  /// Pools where every member is already tracked — surfaced as "complete"
  /// so the user knows the bundle is fully covered.
  List<CompanionPool> completedPools(Set<String> trackedTypeKeys) {
    return pools
        .where(
          (p) => p.members.every((m) => trackedTypeKeys.contains(m.name)),
        )
        .toList(growable: false);
  }

  /// True when [pool] is fully covered by [trackedTypeKeys].
  static bool isPoolComplete(CompanionPool pool, Set<String> trackedTypeKeys) =>
      pool.members.every((m) => trackedTypeKeys.contains(m.name));
}
