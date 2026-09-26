import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/models/document_collection.dart';
import 'package:finavig/models/subscription_tier.dart';
import 'package:finavig/screens/home_screen.dart';
import 'package:finavig/screens/profile_screen.dart';
import 'package:finavig/services/collection_service.dart';
import 'package:finavig/services/entitlement_service.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/dialogs/upgrade_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EntitlementService.instance.reset();
    await EntitlementService.instance.init();
    await DocumentCollectionService.instance.reset();
  });

  group('Plan restrictions and collection locking unit tests', () {
    test('Free tier allows 0 company collections and locks any existing ones', () async {
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.free);
      expect(EntitlementService.instance.tier, SubscriptionTier.free);
      expect(EntitlementService.instance.limits.maxCompanyCollections, 0);

      // Personal collection is never locked
      const personal = DocumentCollection.personal();
      expect(EntitlementService.instance.isCollectionLocked(personal), false);

      // Pre-existing company collection (e.g. from past plus subscription)
      const company1 = DocumentCollection(
        id: 'company-1',
        name: 'Alpha LLC',
        countryCode: 'AE',
      );
      expect(EntitlementService.instance.isCollectionLocked(company1), true);
      expect(
        EntitlementService.instance.requiredTierForCollection(company1),
        SubscriptionTier.plus,
      );
    });

    test('Plus tier unlocks first company collection and locks 2nd+ ones', () async {
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.plus);
      expect(EntitlementService.instance.tier, SubscriptionTier.plus);
      expect(EntitlementService.instance.limits.maxCompanyCollections, 1);

      // Create 1 company collection on Plus
      final c1 = await DocumentCollectionService.instance.createCollection('Company One');
      expect(EntitlementService.instance.isCollectionLocked(c1), false);
      expect(EntitlementService.instance.lockedCollectionsCount, 0);
      expect(EntitlementService.instance.hasAnyLockedCollections, false);

      // Attempting to create 2nd company collection on Plus throws StateError
      expect(
        () => DocumentCollectionService.instance.createCollection('Company Two'),
        throwsA(isA<StateError>()),
      );
    });

    test('Business tier allows unlimited company collections with none locked', () async {
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.business);
      expect(EntitlementService.instance.tier, SubscriptionTier.business);
      expect(EntitlementService.instance.limits.maxCompanyCollections, null);

      final c1 = await DocumentCollectionService.instance.createCollection('Company One');
      final c2 = await DocumentCollectionService.instance.createCollection('Company Two');
      final c3 = await DocumentCollectionService.instance.createCollection('Company Three');

      expect(EntitlementService.instance.isCollectionLocked(c1), false);
      expect(EntitlementService.instance.isCollectionLocked(c2), false);
      expect(EntitlementService.instance.isCollectionLocked(c3), false);
      expect(EntitlementService.instance.lockedCollectionsCount, 0);
      expect(EntitlementService.instance.hasAnyLockedCollections, false);
    });

    test('Downgrade / Expiry locks surplus collections and resets active collection to Personal', () async {
      // 1. Create 2 company collections while on Business tier
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.business);
      final c1 = await DocumentCollectionService.instance.createCollection('Company One');
      final c2 = await DocumentCollectionService.instance.createCollection('Company Two');

      await DocumentCollectionService.instance.setActive(c2.id);
      expect(DocumentCollectionService.instance.activeCollectionId, c2.id);

      // 2. Plan expires / downgraded to Free
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.free);
      expect(EntitlementService.instance.isCollectionLocked(c1), true);
      expect(EntitlementService.instance.isCollectionLocked(c2), true);
      expect(EntitlementService.instance.lockedCollectionsCount, 2);
      expect(EntitlementService.instance.hasAnyLockedCollections, true);

      // Active collection automatically switches away from locked collection to Personal
      expect(
        DocumentCollectionService.instance.activeCollectionId,
        DocumentCollection.personalId,
      );

      // Cannot setActive to a locked collection
      final success = await DocumentCollectionService.instance.setActive(c1.id);
      expect(success, false);
      expect(
        DocumentCollectionService.instance.activeCollectionId,
        DocumentCollection.personalId,
      );

      // 3. Upgrade to Plus: 1st collection unlocks, 2nd remains locked
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.plus);
      expect(EntitlementService.instance.isCollectionLocked(c1), false);
      expect(EntitlementService.instance.isCollectionLocked(c2), true);
      expect(EntitlementService.instance.lockedCollectionsCount, 1);

      // Can activate c1 now
      final activatedC1 = await DocumentCollectionService.instance.setActive(c1.id);
      expect(activatedC1, true);
      expect(DocumentCollectionService.instance.activeCollectionId, c1.id);

      // Still cannot activate c2 on Plus
      final activatedC2 = await DocumentCollectionService.instance.setActive(c2.id);
      expect(activatedC2, false);
      expect(DocumentCollectionService.instance.activeCollectionId, c1.id);
    });
  });

  group('UI & Widget tests for locked collections', () {
    testWidgets('ProfileScreen renders LOCKED badge for locked collections', (tester) async {
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.business);
      await DocumentCollectionService.instance.createCollection('Alpha Corp');
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.free);

      await tester.pumpWidget(
        MaterialApp(
          theme: FinavigTheme.light(),
          home: const ProfileScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Alpha Corp'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);
    });

    testWidgets('HomeScreen renders Plan Restriction banner when collections are locked', (tester) async {
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.business);
      await DocumentCollectionService.instance.createCollection('Beta Corp');
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.free);

      await tester.pumpWidget(
        MaterialApp(
          theme: FinavigTheme.light(),
          home: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1 collection locked'), findsOneWidget);
      expect(find.text('Renew'), findsOneWidget);
    });
  });
}
