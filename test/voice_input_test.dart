import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/services/natural_language_parser_service.dart';
import 'package:finavig/services/voice_input_service.dart';

void main() {
  group('VoiceInputService.parseWordNumber', () {
    test('parses simple units', () {
      expect(VoiceInputService.parseWordNumber('four'), 4);
      expect(VoiceInputService.parseWordNumber('nine'), 9);
    });

    test('parses teens and tens', () {
      expect(VoiceInputService.parseWordNumber('fifteen'), 15);
      expect(VoiceInputService.parseWordNumber('fifty'), 50);
      expect(VoiceInputService.parseWordNumber('eighty five'), 85);
    });

    test('parses hyphenated compounds', () {
      expect(VoiceInputService.parseWordNumber('forty-five'), 45);
      expect(VoiceInputService.parseWordNumber('twenty-one'), 21);
    });

    test('parses hundreds with and without British and', () {
      expect(VoiceInputService.parseWordNumber('four hundred'), 400);
      expect(VoiceInputService.parseWordNumber('four hundred fifty'), 450);
      expect(VoiceInputService.parseWordNumber('four hundred and fifty'), 450);
    });

    test('parses thousands', () {
      expect(VoiceInputService.parseWordNumber('twelve thousand'), 12000);
      expect(VoiceInputService.parseWordNumber('two thousand five hundred'), 2500);
    });

    test('returns null for non-numeric words', () {
      expect(VoiceInputService.parseWordNumber('dewa'), isNull);
      expect(VoiceInputService.parseWordNumber(''), isNull);
    });
  });

  group('VoiceInputService.normalizeTranscript', () {
    test('converts word-numbers to digits in full sentences', () {
      expect(
        VoiceInputService.normalizeTranscript('paid four hundred fifty dirhams for dewa'),
        'paid 450 AED for dewa',
      );
      expect(
        VoiceInputService.normalizeTranscript('received twelve thousand dirhams client payment'),
        'received 12000 AED client payment',
      );
    });

    test('converts spelled currency to AED', () {
      expect(
        VoiceInputService.normalizeTranscript('spent 85 dirhams on uber'),
        'spent 85 AED on uber',
      );
      expect(
        VoiceInputService.normalizeTranscript('rent 15000 dhs'),
        'rent 15000 AED',
      );
    });

    test('collapses hyphens between number words then converts', () {
      expect(
        VoiceInputService.normalizeTranscript('paid forty-five dhs for parking'),
        'paid 45 AED for parking',
      );
    });

    test('leaves digit input untouched except currency', () {
      expect(
        VoiceInputService.normalizeTranscript('Paid 450 AED for DEWA yesterday'),
        'Paid 450 AED for DEWA yesterday',
      );
    });

    test('collapses whitespace', () {
      expect(
        VoiceInputService.normalizeTranscript('  paid   100   dirhams  '),
        'paid 100 AED',
      );
    });
  });

  group('Voice transcript → NaturalLanguageParserService pipeline', () {
    test('voice money transcript parses into a valid transaction', () {
      // Simulates what the mic hears for "Paid 450 AED for DEWA yesterday".
      final spoken = VoiceInputService.normalizeTranscript(
        'paid four hundred fifty dirhams for dewa yesterday',
      );
      final parsed = NaturalLanguageParserService.instance.parseMoney(spoken);

      expect(parsed.amount, 450.0);
      expect(parsed.kind, FinanceKind.expense);
      expect(parsed.category, FinanceCategory.utilities);
      expect(parsed.hasExtractedAmount, isTrue);
      expect(parsed.hasExtractedDate, isTrue);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      expect(parsed.occurredAt.day, yesterday.day);
      expect(parsed.occurredAt.month, yesterday.month);
    });

    test('voice document transcript parses into a valid document item', () {
      final spoken = VoiceInputService.normalizeTranscript(
        'add my trade licence expires twelve march two thousand twenty seven cost one thousand five hundred dirhams',
      );
      final parsed = NaturalLanguageParserService.instance.parse(spoken);

      expect(parsed.hasExtractedDate, isTrue);
      expect(parsed.expiryDate.year, 2027);
      expect(parsed.expiryDate.month, 3);
      expect(parsed.expiryDate.day, 12);
      expect(parsed.renewalFee, 1500.0);
      expect(parsed.docType.key, 'tradeLicence');
    });

    test('voice income transcript parses as income with sales category', () {
      final spoken = VoiceInputService.normalizeTranscript(
        'received twelve thousand dirhams client payment from acme',
      );
      final parsed = NaturalLanguageParserService.instance.parseMoney(spoken);

      expect(parsed.amount, 12000.0);
      expect(parsed.kind, FinanceKind.income);
      expect(parsed.category, FinanceCategory.sales);
    });
  });
}
