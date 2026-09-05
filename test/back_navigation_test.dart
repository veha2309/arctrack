import 'package:arctrack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Android back returns home then requires a second press to exit',
      (tester) async {
    var exits = 0;
    final router = GoRouter(
      initialLocation: '/plan',
      routes: [
        ShellRoute(
          builder: (_, state, child) => AppShell(
            location: state.uri.path,
            exitApp: () => exits++,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/today',
              builder: (_, __) => const Text('Today'),
            ),
            GoRoute(
              path: '/plan',
              builder: (_, __) => const Text('Plan'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
    ));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/today');
    expect(exits, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(exits, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 1);

    router.dispose();
  });
}
