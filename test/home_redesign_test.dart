import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazy/router.dart';
import 'package:wazy/screens/home_screen.dart';
import 'package:wazy/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: WazyTheme.light(), home: const HomeScreen()),
    );
    // _loadData: collection + items + finance init.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('home renders hero header and categories grid', (tester) async {
    await pumpHome(tester);

    // Hero header content.
    expect(find.text('Net this month'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);

    // Content sheet sections.
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    // Month card was removed — its details live in the hero header.
    expect(find.text('This month'), findsNothing);
  });

  testWidgets('floating nav pill stays compact at the bottom of the shell',
      (tester) async {
    // Supabase is unavailable in tests → auth gate is off → /home renders.
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(seconds: 2)); // splash delay elapses
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Home tab content is showing.
    expect(find.text('Net this month'), findsOneWidget);

    // The active home icon sits in the bottom ~12% of the screen — not
    // stretched across the full height (regression: unbounded nav pill).
    // Nav items are located via their tooltips (grid tiles reuse icons).
    final iconCenter = tester.getCenter(find.byTooltip('Home'));
    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(iconCenter.dy, greaterThan(screenH * 0.85));

    // All four tab destinations are present (center search action was
    // removed from the pill).
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Money'), findsOneWidget);
    expect(find.byTooltip('Documents'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.byTooltip('Search'), findsNothing);

    // Tap the Money tab through the pill and back home.
    await tester.tap(find.byTooltip('Money'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Add Record'), findsWidgets);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Net this month'), findsOneWidget);
  });

  testWidgets('category tiles navigate to their own pages', (tester) async {
    // Device-like viewport: the whole categories grid is on screen.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Real router: the tiles navigate via context.push.
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(seconds: 2)); // splash delay elapses
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Budgets tile → /budgets (BudgetsScreen), not the full Money tab.
    await tester.tap(find.text('Budgets'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Overall Monthly Budget'), findsOneWidget);

    // Back home for the next tile.
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Records tile → /records (grouped transaction log).
    await tester.tap(find.text('Records'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Add Record'), findsWidgets);

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Envelopes tile → /envelopes.
    await tester.tap(find.text('Envelopes'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Savings envelopes'), findsOneWidget);
  });

  testWidgets('hero Record pill opens the add-record sheet on Home',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The Money tab's add-record form sheet, opened in place.
    expect(find.text('Add record'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
  });
}
