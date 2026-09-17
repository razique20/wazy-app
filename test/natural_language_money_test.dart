import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/finance.dart';
import 'package:wazy/services/natural_language_parser_service.dart';

void main() {
  group('NaturalLanguageParserService parseMoney Tests', () {
    final parser = NaturalLanguageParserService.instance;

    test('Parses expense prompt: "Paid 450 AED for DEWA electricity yesterday"', () {
      const prompt = 'Paid 450 AED for DEWA electricity yesterday';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.utilities));
      expect(res.amount, equals(450.0));
      expect(res.title, contains('Dewa Electricity'));
      expect(res.hasExtractedAmount, isTrue);
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses income prompt: "Received 12,000 AED client payment from Acme"', () {
      const prompt = 'Received 12,000 AED client payment from Acme';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.income));
      expect(res.category, equals(FinanceCategory.sales));
      expect(res.amount, equals(12000.0));
      expect(res.title, contains('Acme'));
      expect(res.hasExtractedAmount, isTrue);
    });

    test('Parses transport prompt: "Spent 85 AED on Uber transport today"', () {
      const prompt = 'Spent 85 AED on Uber transport today';
      final res = parser.parseMoney(prompt);

      expect(res.kind, equals(FinanceKind.expense));
      expect(res.category, equals(FinanceCategory.transport));
      expect(res.amount, equals(85.0));
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
    });
  });
}
