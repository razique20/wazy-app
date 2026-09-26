import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/services/natural_language_parser_service.dart';

void main() {
  group('NaturalLanguageParserService parseMoney Tests', () {
    final parser = NaturalLanguageParserService.instance;

    test('Parses user complaint prompt: "paid 400 for food"', () {
      const prompt = 'paid 400 for food';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.foodAndBeverages));
      expect(res.amount, equals(400.0));
      expect(res.title, equals('Food'));
      expect(res.hasExtractedAmount, isTrue);
    });

    test('Parses coffee prompt: "spent 50 on coffee"', () {
      const prompt = 'spent 50 on coffee';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.foodAndBeverages));
      expect(res.amount, equals(50.0));
      expect(res.title, equals('Coffee'));
    });

    test('Parses groceries prompt: "grocery shopping 250 dirhams"', () {
      const prompt = 'grocery shopping 250 dirhams';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.foodAndBeverages));
      expect(res.amount, equals(250.0));
      expect(res.title, equals('Grocery Shopping'));
    });

    test('Parses medical pharmacy prompt: "pharmacy 80 AED"', () {
      const prompt = 'pharmacy 80 AED';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.medical));
      expect(res.amount, equals(80.0));
      expect(res.title, equals('Pharmacy'));
    });

    test('Parses shopping prompt: "bought shoes 350 AED"', () {
      const prompt = 'bought shoes 350 AED';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.shopping));
      expect(res.amount, equals(350.0));
      expect(res.title, equals('Shoes'));
    });

    test('Parses entertainment prompt: "cinema movie tickets 120"', () {
      const prompt = 'cinema movie tickets 120';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.entertainment));
      expect(res.amount, equals(120.0));
      expect(res.title, equals('Cinema Movie Tickets'));
    });

    test('Parses expense prompt: "Paid 450 AED for DEWA electricity yesterday"', () {
      const prompt = 'Paid 450 AED for DEWA electricity yesterday';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.utilities));
      expect(res.amount, equals(450.0));
      expect(res.title, equals('Dewa Electricity'));
      expect(res.hasExtractedAmount, isTrue);
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses income prompt: "Received 12,000 AED client payment from Acme"', () {
      const prompt = 'Received 12,000 AED client payment from Acme';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.income));
      expect(res.category, equals(FinanceCategory.sales));
      expect(res.amount, equals(12000.0));
      expect(res.title, equals('Acme'));
      expect(res.hasExtractedAmount, isTrue);
    });

    test('Parses transport prompt: "Spent 85 AED on Uber transport today"', () {
      const prompt = 'Spent 85 AED on Uber transport today';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.transport));
      expect(res.amount, equals(85.0));
      expect(res.title, equals('Uber Transport'));
    });

    test('Parses recurring rent prompt: "Office rent 15000 AED recurring monthly"', () {
      const prompt = 'Office rent 15000 AED recurring monthly';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.rent));
      expect(res.amount, equals(15000.0));
      expect(res.isRecurring, isTrue);
      expect(res.frequency, equals(RecurrenceFrequency.monthly));
    });

    test('Parses software subscription: "Monthly software subscription 99 AED"', () {
      const prompt = 'Monthly software subscription 99 AED';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.software));
      expect(res.amount, equals(99.0));
      expect(res.isRecurring, isTrue);
    });

    test('Parses salary income: "Got 18k AED salary from company"', () {
      const prompt = 'Got 18k AED salary from company';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.income));
      expect(res.category, equals(FinanceCategory.salaries));
      expect(res.amount, equals(18000.0));
      expect(res.title, equals('Company'));
    });
  });
}
