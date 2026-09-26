import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/subscription_tier.dart';
import 'package:finavig/services/ai_executive_summary_service.dart';
import 'package:finavig/services/entitlement_service.dart';
import 'package:finavig/services/groq_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EntitlementService.instance.refresh();
    await AiExecutiveSummaryService.instance.resetUsageCounter();
  });

  group('GroqApiService', () {
    test('uses embedded default Groq API key out-of-the-box', () async {
      final service = GroqApiService.instance;
      expect(service.apiKey, isNotEmpty);
      expect(service.apiKey, startsWith('gsk_'));
      expect(service.isConfigured, isTrue);
    });

    test('supports setting and clearing custom API key override', () async {
      final service = GroqApiService.instance;
      const customKey = 'gsk_custom_test_key_123456789';

      await service.setCustomApiKey(customKey);
      expect(service.apiKey, equals(customKey));

      await service.clearCustomApiKey();
      expect(service.apiKey, startsWith('gsk_'));
    });
  });

  group('Tier Quotas for Groq AI Summary', () {
    test('Free tier allows exactly 3 monthly summaries', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'free'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.free);
      final service = AiExecutiveSummaryService.instance;
      expect(service.getMonthlyQuotaLimit(), 3);

      expect(await service.canGenerateAiSummary(), isTrue);
      expect(await service.getRemainingQuotaThisMonth(), 3);
    });

    test('Plus tier allows exactly 15 monthly summaries', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'plus'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.plus);
      final service = AiExecutiveSummaryService.instance;
      expect(service.getMonthlyQuotaLimit(), 15);
    });

    test('Business tier allows exactly 40 monthly summaries', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'business'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.business);
      final service = AiExecutiveSummaryService.instance;
      expect(service.getMonthlyQuotaLimit(), 40);
    });
  });

  group('AiExecutiveSummaryService Generation & Fallback', () {
    test('generates summary using Groq override and increments monthly counter', () async {
      final service = AiExecutiveSummaryService.instance;
      service.groqCallOverride = (system, user) async =>
          'Executive AI Summary: 2 documents require renewal. Monthly spending is AED 5,400.';

      final now = DateTime(2026, 9, 21);
      final result = await service.generateSummary(forceRegenerate: true, now: now);

      expect(result.usedGroq, isTrue);
      expect(result.quotaExceeded, isFalse);
      expect(result.narrative, contains('Executive AI Summary'));
      expect(await service.getUsedQuotaThisMonth(now), 1);
      expect(await service.getRemainingQuotaThisMonth(now), 2);
    });

    test('enforces quota limit when limit is reached', () async {
      final service = AiExecutiveSummaryService.instance;
      service.groqCallOverride = (system, user) async => 'AI Summary Text';

      final now = DateTime(2026, 9, 21);
      // Generate 3 times (Free tier limit)
      await service.generateSummary(forceRegenerate: true, now: now);
      await service.generateSummary(forceRegenerate: true, now: now);
      await service.generateSummary(forceRegenerate: true, now: now);

      expect(await service.getUsedQuotaThisMonth(now), 3);
      expect(await service.canGenerateAiSummary(now), isFalse);

      // 4th generation should trigger quotaExceeded and return fallback narrative without crashing
      final overflowResult = await service.generateSummary(forceRegenerate: true, now: now);
      expect(overflowResult.quotaExceeded, isTrue);
      expect(overflowResult.usedGroq, isFalse);
    });
  });
}
