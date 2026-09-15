import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/finance.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'supabase_service.dart';

/// Store for the signed-in user's finance records: transactions, category
/// budgets and savings envelopes — all scoped to a [DocumentCollection].
///
/// Follows the same pattern as DocumentScannerService:
/// * Singleton + [ChangeNotifier] so screens can listen.
/// * Supabase-backed when credentials exist (tables: finance_transactions,
///   category_budgets, savings_envelopes — see supabase/schema.sql).
/// * Local-only mode: records persist to SharedPreferences as JSON so the
///   finance module stays fully usable offline.
class FinanceService extends ChangeNotifier {
  FinanceService._();

  static final FinanceService instance = FinanceService._();

  factory FinanceService() => instance;

  static const String _localStoreKey = 'financeRecords.v1';

  final _client =
      SupabaseService.hasCredentials ? SupabaseService.client : null;

  final List<FinanceTransaction> _transactions = [];
  final List<CategoryBudget> _budgets = [];
  final List<SavingsEnvelope> _envelopes = [];
  final Map<String, double> _overallBudgets = {};
  bool _initialized = false;

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);

  List<CategoryBudget> get budgets => List.unmodifiable(_budgets);

  List<SavingsEnvelope> get envelopes => List.unmodifiable(_envelopes);

  /// Overall monthly budget for the active collection (if set).
  double? get activeOverallBudget {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    return _overallBudgets[activeId];
  }

  /// All records scoped to the active collection.
  List<FinanceTransaction> get activeTransactions {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    return _transactions.where((t) => t.collectionId == activeId).toList();
  }

  List<CategoryBudget> get activeBudgets {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    return _budgets.where((b) => b.collectionId == activeId).toList();
  }

  List<SavingsEnvelope> get activeEnvelopes {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    return _envelopes.where((e) => e.collectionId == activeId).toList();
  }

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final client = _client;
    final userId = AuthService.instance.currentUserId;

    if (client == null || userId == null) {
      await _loadLocal();
      return;
    }

    try {
      final txRows = await client
          .from('finance_transactions')
          .select()
          .eq('owner_id', userId)
          .order('occurred_at', ascending: false);
      _transactions
        ..clear()
        ..addAll(txRows.map(_txRowToModel));

      final budgetRows = await client
          .from('category_budgets')
          .select()
          .eq('owner_id', userId);
      _budgets
        ..clear()
        ..addAll(budgetRows.map(_budgetRowToModel));

      final envelopeRows = await client
          .from('savings_envelopes')
          .select()
          .eq('owner_id', userId);
      _envelopes
        ..clear()
        ..addAll(envelopeRows.map(_envelopeRowToModel));
    } catch (_) {
      // Supabase unreachable or tables missing — fall back to local store
      // so the finance module keeps working offline.
      await _loadLocal();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _initialized = false;
    await init();
  }

  /// Drop all cached data (used on sign-out).
  void clearCache() {
    _transactions.clear();
    _budgets.clear();
    _envelopes.clear();
    _initialized = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Writes — transactions
  // ------------------------------------------------------------------

  Future<void> addTransaction(FinanceTransaction transaction) async {
    final scoped = transaction.collectionId.isEmpty
        ? _withActiveCollection(transaction)
        : transaction;

    final client = _client;
    if (client != null && AuthService.instance.currentUserId != null) {
      try {
        await client.from('finance_transactions').insert(
              _txModelToRow(scoped, ownerId: AuthService.instance.currentUserId),
            );
      } catch (_) {
        // Non-fatal: keep the record locally so nothing is lost.
      }
    }

    _transactions.insert(0, scoped);
    await _persistLocal();
    notifyListeners();
  }

  Future<void> updateTransaction(FinanceTransaction updated) async {
    final client = _client;
    if (client != null) {
      try {
        await client
            .from('finance_transactions')
            .update(_txModelToRow(updated))
            .eq('id', updated.id);
      } catch (_) {
        // Non-fatal.
      }
    }
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index != -1) _transactions[index] = updated;
    await _persistLocal();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from('finance_transactions').delete().eq('id', id);
      } catch (_) {
        // Non-fatal.
      }
    }
    _transactions.removeWhere((t) => t.id == id);
    await _persistLocal();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Writes — budgets
  // ------------------------------------------------------------------

  /// Create a budget, or update the limit if one already exists for the
  /// category in the active collection.
  Future<CategoryBudget> upsertBudget(
    FinanceCategory category,
    double monthlyLimit,
  ) async {
    final existing = activeBudgets
        .where((b) => b.category == category)
        .firstOrNull;

    if (existing != null) {
      final updated = existing.copyWith(monthlyLimit: monthlyLimit);
      final client = _client;
      if (client != null) {
        try {
          await client
              .from('category_budgets')
              .update({'monthly_limit': monthlyLimit})
              .eq('id', existing.id);
        } catch (_) {
          // Non-fatal.
        }
      }
      final index = _budgets.indexWhere((b) => b.id == existing.id);
      if (index != -1) _budgets[index] = updated;
      await _persistLocal();
      notifyListeners();
      return updated;
    }

    final budget = CategoryBudget(
      id: const Uuid().v4(),
      collectionId: DocumentCollectionService.instance.activeCollectionId,
      category: category,
      monthlyLimit: monthlyLimit,
    );
    final client = _client;
    if (client != null && AuthService.instance.currentUserId != null) {
      try {
        await client.from('category_budgets').insert(
              _budgetModelToRow(budget,
                  ownerId: AuthService.instance.currentUserId!),
            );
      } catch (_) {
        // Non-fatal.
      }
    }
    _budgets.add(budget);
    await _persistLocal();
    notifyListeners();
    return budget;
  }

  Future<void> deleteBudget(String id) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from('category_budgets').delete().eq('id', id);
      } catch (_) {
        // Non-fatal.
      }
    }
    _budgets.removeWhere((b) => b.id == id);
    await _persistLocal();
    notifyListeners();
  }

  /// Set or clear the overall monthly budget for the active collection.
  Future<void> setOverallBudget(double? amount) async {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    if (amount == null || amount <= 0) {
      _overallBudgets.remove(activeId);
    } else {
      _overallBudgets[activeId] = amount;
    }
    await _persistLocal();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Writes — envelopes
  // ------------------------------------------------------------------

  Future<SavingsEnvelope> addEnvelope(
    String name,
    double targetAmount,
    double monthlyContribution, {
    String? documentId,
  }) async {
    final envelope = SavingsEnvelope(
      id: const Uuid().v4(),
      collectionId: DocumentCollectionService.instance.activeCollectionId,
      name: name,
      targetAmount: targetAmount,
      monthlyContribution: monthlyContribution,
      documentId: documentId,
    );
    final client = _client;
    if (client != null && AuthService.instance.currentUserId != null) {
      try {
        await client.from('savings_envelopes').insert(
              _envelopeModelToRow(envelope,
                  ownerId: AuthService.instance.currentUserId!),
            );
      } catch (_) {
        // Non-fatal.
      }
    }
    _envelopes.add(envelope);
    await _persistLocal();
    notifyListeners();
    return envelope;
  }

  /// Move money into / out of an envelope. Tracking only — no real money
  /// moves (pre-licence posture, see FINTECH_ROADMAP.md).
  Future<void> adjustEnvelope(String id, double delta) async {
    final index = _envelopes.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final current = _envelopes[index];
    final newSaved =
        (current.savedAmount + delta).clamp(0.0, double.infinity);
    final updated = current.copyWith(savedAmount: newSaved);

    final client = _client;
    if (client != null) {
      try {
        await client
            .from('savings_envelopes')
            .update({'saved_amount': newSaved})
            .eq('id', id);
      } catch (_) {
        // Non-fatal.
      }
    }
    _envelopes[index] = updated;
    await _persistLocal();
    notifyListeners();
  }

  Future<void> deleteEnvelope(String id) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from('savings_envelopes').delete().eq('id', id);
      } catch (_) {
        // Non-fatal.
      }
    }
    _envelopes.removeWhere((e) => e.id == id);
    await _persistLocal();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  FinanceTransaction _withActiveCollection(FinanceTransaction t) =>
      t.copyWith(
        collectionId: DocumentCollectionService.instance.activeCollectionId,
      );

  Future<void> _persistLocal() async {
    if (_client != null && AuthService.instance.currentUserId != null) {
      return; // Supabase is the source of truth when connected.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localStoreKey,
      jsonEncode({
        'transactions': _transactions.map((t) => t.toJson()).toList(),
        'budgets': _budgets.map((b) => b.toJson()).toList(),
        'envelopes': _envelopes.map((e) => e.toJson()).toList(),
        'overallBudgets': _overallBudgets,
      }),
    );
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localStoreKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _transactions
        ..clear()
        ..addAll(
          (decoded['transactions'] as List<dynamic>? ?? const [])
              .map((json) => FinanceTransaction.fromJson(json as Map<String, dynamic>)),
        );
      _budgets
        ..clear()
        ..addAll(
          (decoded['budgets'] as List<dynamic>? ?? const [])
              .map((json) => CategoryBudget.fromJson(json as Map<String, dynamic>)),
        );
      _envelopes
        ..clear()
        ..addAll(
          (decoded['envelopes'] as List<dynamic>? ?? const [])
              .map((json) => SavingsEnvelope.fromJson(json as Map<String, dynamic>)),
        );
      _overallBudgets.clear();
      if (decoded['overallBudgets'] is Map<String, dynamic>) {
        (decoded['overallBudgets'] as Map<String, dynamic>).forEach((key, val) {
          if (val is num) _overallBudgets[key] = val.toDouble();
        });
      }
    } catch (_) {
      // Ignore malformed cache — start empty rather than crash.
    }
  }

  // ------------------------------------------------------------------
  // DB row ↔ model
  // ------------------------------------------------------------------

  static FinanceTransaction _txRowToModel(Map<String, dynamic> row) {
    return FinanceTransaction(
      id: row['id'] as String,
      collectionId:
          row['collection_id'] as String? ?? 'personal',
      kind: row['kind'] == 'income' ? FinanceKind.income : FinanceKind.expense,
      category: FinanceCategoryX.fromName(row['category'] as String?),
      title: row['title'] as String? ?? 'Transaction',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'AED',
      occurredAt:
          DateTime.tryParse(row['occurred_at'] as String? ?? '') ??
              DateTime.now(),
      note: row['note'] as String?,
      documentId: row['document_id'] as String?,
    );
  }

  static Map<String, dynamic> _txModelToRow(
    FinanceTransaction t, {
    String? ownerId,
  }) {
    final row = <String, dynamic>{
      'id': t.id,
      'collection_id': t.collectionId,
      'kind': t.kind.name,
      'category': t.category.name,
      'title': t.title,
      'amount': t.amount,
      'currency': t.currency,
      'occurred_at': t.occurredAt.toIso8601String().split('T').first,
      'note': t.note,
      'document_id': t.documentId,
    };
    if (ownerId != null) row['owner_id'] = ownerId;
    return row;
  }

  static CategoryBudget _budgetRowToModel(Map<String, dynamic> row) {
    return CategoryBudget(
      id: row['id'] as String,
      collectionId: row['collection_id'] as String? ?? 'personal',
      category: FinanceCategoryX.fromName(row['category'] as String?),
      monthlyLimit: (row['monthly_limit'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _budgetModelToRow(
    CategoryBudget b, {
    required String ownerId,
  }) {
    return {
      'id': b.id,
      'owner_id': ownerId,
      'collection_id': b.collectionId,
      'category': b.category.name,
      'monthly_limit': b.monthlyLimit,
    };
  }

  static SavingsEnvelope _envelopeRowToModel(Map<String, dynamic> row) {
    return SavingsEnvelope(
      id: row['id'] as String,
      collectionId: row['collection_id'] as String? ?? 'personal',
      name: row['name'] as String? ?? 'Envelope',
      targetAmount: (row['target_amount'] as num?)?.toDouble() ?? 0,
      savedAmount: (row['saved_amount'] as num?)?.toDouble() ?? 0,
      monthlyContribution:
          (row['monthly_contribution'] as num?)?.toDouble() ?? 0,
      documentId: row['document_id'] as String?,
    );
  }

  static Map<String, dynamic> _envelopeModelToRow(
    SavingsEnvelope e, {
    required String ownerId,
  }) {
    return {
      'id': e.id,
      'owner_id': ownerId,
      'collection_id': e.collectionId,
      'name': e.name,
      'target_amount': e.targetAmount,
      'saved_amount': e.savedAmount,
      'monthly_contribution': e.monthlyContribution,
      'document_id': e.documentId,
    };
  }
}
