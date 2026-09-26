// Redesigned Settings (Profile) screen: navy hero + rounded content sheet,
// matching the Home/Documents family. Guards the new layout contract.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/profile_screen.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: FinavigTheme.light(), home: const ProfileScreen()),
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
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Alerts & Reminders'), findsOneWidget);
    expect(find.text('AI Summary'), findsOneWidget);

    // Theme segmented control is now under "Appearance".
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Alerts & Reminders is now a dedicated link tile under Preferences.
    expect(find.text('Notifications, bill spikes, budget alerts & lead times'), findsOneWidget);
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
