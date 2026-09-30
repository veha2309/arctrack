import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/plan_screen.dart';
import 'ui/screens/progress_screen.dart';
import 'ui/screens/today_screen.dart';
import 'ui/screens/workout_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ArcTrackApp()));
}

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/today',
      routes: [
        ShellRoute(
            builder: (context, state, child) =>
                AppShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
              GoRoute(path: '/plan', builder: (_, __) => const PlanScreen()),
              GoRoute(
                  path: '/workout', builder: (_, __) => const WorkoutScreen()),
              GoRoute(
                  path: '/progress',
                  builder: (_, __) => const ProgressScreen()),
            ]),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      ],
    ));

class ArcTrackApp extends ConsumerWidget {
  const ArcTrackApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
      title: 'ArcTrack',
      debugShowCheckedModeBanner: false,
      theme: arcTheme(),
      routerConfig: ref.watch(routerProvider));
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.exitApp,
  });
  final String location;
  final Widget child;
  final VoidCallback? exitApp;
  static const paths = ['/today', '/workout', '/plan', '/progress'];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _navigationChannel =
      MethodChannel('com.arctrack.arctrack/navigation');
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _navigationChannel.setMethodCallHandler((call) async {
      if (call.method != 'systemBack') return null;
      return _handleBackRequest(exitFromFlutter: false);
    });
  }

  @override
  void dispose() {
    _navigationChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<bool> _handleBackRequest({required bool exitFromFlutter}) async {
    if (widget.location != '/today') {
      _lastBackPressed = null;
      context.go('/today');
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressed != null &&
        now.difference(_lastBackPressed!) < const Duration(seconds: 2)) {
      if (exitFromFlutter) (widget.exitApp ?? SystemNavigator.pop)();
      return true;
    }

    _lastBackPressed = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ));
    return false;
  }

  Future<bool> _handleFlutterBackButton() async {
    await _handleBackRequest(exitFromFlutter: true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final index = AppShell.paths.indexOf(widget.location).clamp(0, 3);
    return BackButtonListener(
      onBackButtonPressed: _handleFlutterBackButton,
      child: Scaffold(
          body: widget.child,
          bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(AppShell.paths[i]),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    selectedIcon: Icon(Icons.fitness_center),
                    label: 'Train'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Program'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: 'Insights'),
              ])),
    );
  }
}
