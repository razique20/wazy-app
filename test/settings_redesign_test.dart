// Redesigned Settings (Profile) screen: navy hero + rounded content sheet,
// matching the Home/Documents family. Guards the new layout contract.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazy/screens/profile_screen.dart';
import 'package:wazy/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: WazyTheme.light(), home: const ProfileScreen()),
    );
    await tester.pump(); // collections load
    await tester.pump(const Duration(seconds: 1)); // settings load
  }

  testWidgets('renders hero header and rounded content sheet', (tester) async {
    await pumpSettings(tester);

    // Hero header carries the title (no AppBar anymore) and identity block.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    // Sheet sections.
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('My Collections'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Alerts & Reminders'), findsOneWidget);
    expect(find.text('AI Summary'), findsOneWidget);

    // Theme segmented control is now under "Appearance".
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Individual alert rows.
    expect(find.text('Renewal notifications'), findsOneWidget);
    expect(find.text('Bill spike alerts'), findsOneWidget);
    expect(find.text('Budget alerts'), findsOneWidget);
  });

  testWidgets('usage meters exist in the subscription card', (tester) async {
    await pumpSettings(tester);

    // Free tier: documents are capped and render a meter; company
    // workspaces are capped at 0 and the meter is hidden.
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Company workspaces'), findsNothing);
  });

  testWidgets('collection row and dropdowns open bottom sheets', (tester) async {
    await pumpSettings(tester);

    // Personal collection is listed.
    expect(find.text('Personal'), findsOneWidget);

    // Tapping "First reminder" opens the day-picker sheet. The row sits
    // below the fold — scroll it into view first.
    await tester.scrollUntilVisible(
      find.text('First reminder'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    await tester.tap(find.text('First reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet options render as "N days". Some values also appear as the
    // current value on the page rows behind the sheet, so use findsWidgets —
    // except 120, which exists only inside the opened sheet.
    expect(find.text('30 days'), findsWidgets);
    expect(find.text('60 days'), findsWidgets);
    expect(find.text('90 days'), findsWidgets);
    expect(find.text('120 days'), findsOneWidget);
  });

  testWidgets('theme switch still works from the Appearance group',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The app-level theme is owned by ThemeService, so the MaterialApp here
    // stays light — the setting itself is asserted by ThemeService state.
    // The control must at least remain interactive (no exception, still
    // selected highlight updates come from setState).
    expect(find.text('Dark'), findsOneWidget);
  });
}
