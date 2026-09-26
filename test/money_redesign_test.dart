// Redesigned Money tab: navy hero + rounded content sheet, matching the
// Home/Documents/Settings family. Guards the new layout contract.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/money_screen.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpMoney(
    WidgetTester tester, {
    void Function(FlutterErrorDetails)? onError,
  }) async {
    if (onError != null) {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        onError(details);
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }
    await tester.pumpWidget(
      MaterialApp(theme: FinavigTheme.light(), home: const MoneyScreen()),
    );
    await tester.pump(); // finance init
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders hero header and rounded content sheet', (tester) async {
    await pumpMoney(tester);

    // Hero carries the title now — the old AppBar and floating button are
    // gone.
    expect(find.text('Money'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Live status line + headline number.
    expect(find.textContaining('0 records'), findsOneWidget);
    expect(find.text('Net this month'), findsOneWidget);
    expect(find.text('AED 0.00 in · AED 0.00 out'), findsOneWidget);

    // Action pills: navigation + primary add action (kept from the old
    // layout's "Add Record" affordance).
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Envelopes'), findsOneWidget);
    expect(find.text('Add Record'), findsOneWidget);

    // Sheet content: sections render inside the rounded sheet.
    expect(find.text('Monthly budgets'), findsOneWidget);
    expect(find.text('Last 6 weeks'), findsOneWidget);
  });

  testWidgets('Add Record pill opens the transaction form sheet',
      (tester) async {
    await pumpMoney(tester);

    await tester.tap(find.text('Add Record'));
    await tester.pumpAndSettle();

    expect(find.text('Add record'), findsOneWidget);
    expect(find.text('Repeat monthly'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('hero action pills fit a narrow phone viewport without '
      'overflowing', (tester) async {
    // iPhone-sized viewport — regression: Budgets + Envelopes + Add Record
    // in a plain Row overflowed the hero on narrow screens.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0; // logical width ≈ 393
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    await pumpMoney(tester, onError: errors.add);

    // All three actions are present and tappable.
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Envelopes'), findsOneWidget);
    expect(find.text('Add Record'), findsOneWidget);

    // No RenderFlex overflow (or any layout exception) may have fired —
    // the old Row-based hero overflowed by 11px on this viewport.
    final overflows = errors
        .map((e) => '${e.exception}\n${e.informationCollector?.call().join('\n') ?? ''}')
        .where((s) => s.contains('overflowed'))
        .toList();
    if (overflows.isNotEmpty) {
      // ignore: avoid_print
      print('OVERFLOW DETAILS:\n${overflows.join('\n---\n')}');
    }
    expect(
      overflows,
      isEmpty,
      reason: 'Hero or sheet rows must not overflow at 393px viewport width.',
    );
  });
}
