import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance.dart';

/// The result of an AI category prediction.
class CategoryPrediction {
  final FinanceCategory category;
  final double confidence; // 0.0 to 1.0
  final String matchSource;

  const CategoryPrediction({
    required this.category,
    required this.confidence,
    required this.matchSource,
  });

  bool get isHighConfidence => confidence >= 0.75;

  @override
  String toString() =>
      'CategoryPrediction(${category.displayName}, confidence: ${(confidence * 100).toStringAsFixed(0)}%, source: $matchSource)';
}

/// Smart Auto-Categorization & Tagging Engine for Finavig.
/// Combines dictionary rules, fuzzy Levenshtein matching, and persistent user habit learning.
class SmartCategoryEngine {
  static final SmartCategoryEngine instance = SmartCategoryEngine._();
  SmartCategoryEngine._();

  static const String _memoryPrefsKey = 'wazy_learned_category_memory_v1';
  Map<String, String> _userLearnedMemory = {};
  bool _isInitialized = false;

  /// Built-in GCC vendor & keyword dictionary.
  static final Map<FinanceCategory, List<String>> _dictionary = {
    FinanceCategory.foodAndBeverages: [
      'talabat', 'deliveroo', 'zomato', 'noon food', 'carrefour', 'spinneys',
      'lulu', 'choithrams', 'viva', 'starbucks', 'costa', 'mcdonalds', 'kfc',
      'cafeteria', 'restaurant', 'cafe', 'lunch', 'dinner', 'breakfast',
      'groceries', 'grocery', 'supermarket', 'snack', 'snacks', 'coffee',
      'food', 'dining', 'meals', 'bakery', 'subway', 'hardees', 'burger',
      'pizza', 'shawarma', 'karak', 'tea'
    ],
    FinanceCategory.transport: [
      'salik', 'rta', 'uber', 'careem', 'taxi', 'petrol', 'enoc', 'adnoc',
      'eppco', 'emarat', 'parking', 'mulkiya', 'moolkiya', 'transport',
      'toll', 'fuel', 'bus', 'metro', 'gasoline', 'oil change', 'car wash'
    ],
    FinanceCategory.utilities: [
      'dewa', 'sewa', 'fewa', 'du', 'etisalat', 'virgin mobile', 'internet',
      'wifi', 'phone', 'mobile', 'electricity', 'water', 'gas', 'utility',
      'utilities', 'bill', 'cooling', 'empower', 'tabreed'
    ],
    FinanceCategory.rent: [
      'ejari', 'tenancy', 'landlord', 'rent', 'office rent', 'apartment rent',
      'housing', 'real estate', 'lease', 'deposite'
    ],
    FinanceCategory.shopping: [
      'amazon', 'noon', 'centerpoint', 'max', 'zara', 'h&m', 'namshi', 'mall',
      'electronics', 'clothes', 'clothing', 'shoes', 'fashion', 'shopping',
      'gift', 'gifts', 'store', 'boutique', 'ikea', 'sharaf dg', 'jumbo'
    ],
    FinanceCategory.medical: [
      'aster', 'life pharmacy', 'boots', 'supercare', 'doctor', 'clinic',
      'hospital', 'pharmacy', 'health', 'healthcare', 'dental', 'dentist',
      'medicine', 'medicines', 'lab', 'checkup', 'nmc', 'mediclinic'
    ],
    FinanceCategory.entertainment: [
      'vox', 'reel', 'cinema', 'netflix', 'spotify', 'playstation', 'xbox',
      'event', 'tickets', 'movie', 'bowling', 'theme park', 'fun', 'game',
      'gaming', 'concert', 'hbo', 'disney+'
    ],
    FinanceCategory.software: [
      'aws', 'google cloud', 'github', 'chatgpt', 'openai', 'figma', 'slack',
      'zoom', 'adobe', 'microsoft', 'hostinger', 'software', 'saas', 'license',
      'domain', 'godaddy', 'canva', 'jetbrains', 'vercel'
    ],
    FinanceCategory.salaries: [
      'salary', 'salaries', 'payroll', 'wage', 'wages', 'bonus', 'mohre',
      'staff pay', 'freelancer', 'employee pay'
    ],
    FinanceCategory.marketing: [
      'google ads', 'facebook ads', 'meta', 'tiktok ads', 'linkedin ads',
      'marketing', 'campaign', 'promotion', 'advertising', 'flyers', 'pr'
    ],
    FinanceCategory.suppliers: [
      'vendor', 'supplier', 'suppliers', 'wholesale', 'inventory', 'stock',
      'materials', 'supply', 'packaging', 'boxes'
    ],
    FinanceCategory.sales: [
      'sales', 'client', 'customer', 'revenue', 'invoice', 'project payment',
      'stripe', 'checkout', 'pos'
    ],
    FinanceCategory.renewals: [
      'trade licence', 'trade license', 'ded', 'det', 'gdrfa', 'visa',
      'insurance', 'renewal', 'licence', 'license'
    ],
  };

  /// Initializes the smart engine and loads user habit memory.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_memoryPrefsKey);
      if (rawJson != null) {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        _userLearnedMemory = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('SmartCategoryEngine init error: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Teaches the engine a user habit when a user manually saves/edits a category.
  Future<void> learnUserChoice(String title, FinanceCategory category) async {
    await init();
    final tokens = _tokenize(title);
    if (tokens.isEmpty) return;

    var updated = false;
    for (final token in tokens) {
      if (token.length >= 3 && !_isStopWord(token)) {
        _userLearnedMemory[token] = category.name;
        updated = true;
      }
    }

    if (updated) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_memoryPrefsKey, jsonEncode(_userLearnedMemory));
      } catch (e) {
        debugPrint('SmartCategoryEngine learn save error: $e');
      }
    }
  }

  /// Predicts the category for an input title or text.
  CategoryPrediction predict(String title, {FinanceKind? kind}) {
    final rawTokens = _tokenize(title);
    if (rawTokens.isEmpty) {
      return _fallbackPrediction(kind);
    }

    // 1. Check User Learned Memory
    for (final token in rawTokens) {
      if (_userLearnedMemory.containsKey(token)) {
        final catName = _userLearnedMemory[token]!;
        final cat = FinanceCategoryX.fromName(catName);
        return CategoryPrediction(
          category: cat,
          confidence: 0.95,
          matchSource: 'Learned Habit ("$token")',
        );
      }
    }

    // 2. Exact Dictionary Match
    for (final entry in _dictionary.entries) {
      final cat = entry.key;
      final keywords = entry.value;
      for (final kw in keywords) {
        for (final token in rawTokens) {
          if (token == kw || (kw.contains(' ') && title.toLowerCase().contains(kw))) {
            return CategoryPrediction(
              category: cat,
              confidence: 0.88,
              matchSource: 'Keyword ("$kw")',
            );
          }
        }
      }
    }

    // 3. Fuzzy Levenshtein Distance Match (handles typos like "Talabt" -> "Talabat")
    CategoryPrediction? bestFuzzyMatch;
    var lowestDist = 999;

    for (final entry in _dictionary.entries) {
      final cat = entry.key;
      final keywords = entry.value;
      for (final kw in keywords) {
        if (kw.contains(' ')) continue; // Skip multi-word phrases for fuzzy token distance
        for (final token in rawTokens) {
          if (token.length < 3 || kw.length < 3) continue;
          final dist = _levenshtein(token, kw);
          // Allow max 1 edit for 4-5 letter words, max 2 edits for 6+ letter words
          final maxAllowedDist = kw.length >= 6 ? 2 : 1;
          if (dist <= maxAllowedDist && dist < lowestDist) {
            lowestDist = dist;
            bestFuzzyMatch = CategoryPrediction(
              category: cat,
              confidence: (0.78 - (dist * 0.05)).clamp(0.65, 0.80),
              matchSource: 'Fuzzy Match ("$token" ≈ "$kw")',
            );
          }
        }
      }
    }

    if (bestFuzzyMatch != null) {
      return bestFuzzyMatch;
    }

    // 4. Fallback
    return _fallbackPrediction(kind);
  }

  /// Automatically re-classifies a list of transactions (or uncategorized ones).
  List<FinanceTransaction> retroApplyCategorization(
    List<FinanceTransaction> transactions, {
    bool onlyUncategorized = false,
  }) {
    final updated = <FinanceTransaction>[];
    for (final tx in transactions) {
      if (onlyUncategorized && tx.category != FinanceCategory.other) {
        updated.add(tx);
        continue;
      }

      final pred = predict(tx.title, kind: tx.kind);
      if (pred.isHighConfidence && pred.category != tx.category) {
        updated.add(tx.copyWith(category: pred.category));
      } else {
        updated.add(tx);
      }
    }
    return updated;
  }

  CategoryPrediction _fallbackPrediction(FinanceKind? kind) {
    if (kind == FinanceKind.income) {
      return const CategoryPrediction(
        category: FinanceCategory.sales,
        confidence: 0.50,
        matchSource: 'Default Income',
      );
    }
    return const CategoryPrediction(
      category: FinanceCategory.other,
      confidence: 0.40,
      matchSource: 'Default Fallback',
    );
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'paid', 'spent', 'bought', 'cost', 'fee', 'aed', 'dirhams', 'dhs',
      'dhm', 'for', 'the', 'and', 'with', 'from', 'today', 'yesterday'
    };
    return stopWords.contains(word);
  }

  /// Levenshtein Distance computation between two strings.
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    final v0 = List<int>.generate(t.length + 1, (i) => i);
    final v1 = List<int>.filled(t.length + 1, 0);
    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
