import 'package:arctrack/ui/common.dart';
import 'package:arctrack/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openHarness(WidgetTester tester) =>
      tester.pumpWidget(MaterialApp(
          theme: arcTheme(),
          home: Scaffold(
              body: Builder(
                  builder: (context) => Column(children: [
                        TextButton(
                            onPressed: () =>
                                showArcToast(context, 'First message'),
                            child: const Text('First')),
                        TextButton(
                            onPressed: () =>
                                showArcToast(context, 'Latest message'),
                            child: const Text('Latest')),
                      ])))));

  testWidgets('package toasts replace older messages and expire',
      (tester) async {
    await openHarness(tester);
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.text('First message'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();
    expect(find.text('First message'), findsNothing);
    expect(find.text('Latest message'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('package toast can be closed immediately', (tester) async {
    await openHarness(tester);
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
