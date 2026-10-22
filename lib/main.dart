import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_ui_components/liquid_ui_components.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/plan_screen.dart';
import 'ui/screens/progress_screen.dart';
import 'ui/screens/today_screen.dart';
import 'ui/screens/workout_screen.dart';
import 'ui/theme.dart';
import 'ui/common.dart';
import 'dart:async';
import 'application/app_controller.dart';
import 'ui/screens/splash_screen.dart';

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
      scrollBehavior: const LiquidGlassScrollBehavior(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => LiquidGlassTheme(
          settings: arcGlassSettings,
          child: DecoratedBox(
              decoration: arcBackground, child: _StartupGate(child: child!))));
}

class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate({required this.child});
  final Widget child;
  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<_StartupGate> {
  Timer? timer;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    return ready && !data.isLoading ? widget.child : const SplashScreen();
  }
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
    showArcToast(context, 'Press back again to exit',
        icon: Icons.info_outline_rounded, duration: const Duration(seconds: 2));
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
          extendBody: true,
          body: SafeArea(top: false, child: widget.child),
          bottomNavigationBar: LiquidGlassNavigationBar(
              selectedIndex: index,
              onTap: (i) => context.go(AppShell.paths[i]),
              tintColor: ArcColors.accent,
              unselectedColor: ArcColors.muted,
              glassSettings: arcGlassSettings,
              items: const [
                LiquidGlassNavigationItem(
                    icon: Icons.grid_view_rounded, label: 'Home'),
                LiquidGlassNavigationItem(
                    icon: Icons.fitness_center, label: 'Train'),
                LiquidGlassNavigationItem(
                    icon: Icons.calendar_month, label: 'Program'),
                LiquidGlassNavigationItem(
                    icon: Icons.insights, label: 'Insights'),
              ])),
    );
  }
}
