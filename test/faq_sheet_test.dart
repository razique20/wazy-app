import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/widgets/dialogs/faq_sheet.dart';

void main() {
  testWidgets('showFaqSheet renders header, search, category chips and FAQ questions', (tester) async {
    bool supportTicketOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFaqSheet(
                ctx,
                onOpenSupportTicket: () => supportTicketOpened = true,
              ),
              child: const Text('Open FAQ'),
            ),
          ),
        ),
      ),
    );

    // Tap to open FAQ sheet
    await tester.tap(find.text('Open FAQ'));
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(find.text('Everything you need to know about Finavig'), findsOneWidget);

    // Verify Search Bar hint
    expect(find.text('Search questions, features, or keywords...'), findsOneWidget);

    // Verify Category Chips
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Documents'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Money'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'AI & Voice'), findsOneWidget);

    // Verify FAQ items present
    expect(find.text('How does Finavig track document expiries?'), findsOneWidget);

    // Filter by category 'Money'
    await tester.tap(find.widgetWithText(ChoiceChip, 'Money'));
    await tester.pumpAndSettle();

    expect(find.text('How does Smart Category matching work?'), findsOneWidget);
    expect(find.text('How does Finavig track document expiries?'), findsNothing);

    // Search query filtering
    await tester.enterText(find.byType(TextField), 'spike');
    await tester.pumpAndSettle();

    expect(find.text('What is a Bill Spike anomaly alert?'), findsOneWidget);

    // Test Contact Support CTA
    expect(find.text('Contact Support'), findsOneWidget);
    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();

    expect(supportTicketOpened, isTrue);
  });
}
