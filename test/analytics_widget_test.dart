import 'package:arctrack/application/app_controller.dart';
import 'package:arctrack/data/app_repository.dart';
import 'package:arctrack/domain/models.dart';
import 'package:arctrack/ui/screens/progress_screen.dart';
import 'package:arctrack/ui/screens/plan_screen.dart';
import 'package:arctrack/ui/screens/today_screen.dart';
import 'package:arctrack/ui/screens/workout_screen.dart';
import 'package:arctrack/ui/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Progress renders a single-point exercise trend and body-weight chart',
      (tester) async {
    final now = DateTime.now();
    final data = seedData().copyWith(
      sessions: [
        WorkoutSession(
          id: 'one',
          name: 'Push',
          startedAt: now,
          completedAt: now,
          exercises: const [
            ExerciseLog(id: 'log', exerciseId: 'bench', sets: [
              LoggedSet(id: 'set', weightKg: 50, reps: 5, completed: true),
            ])
          ],
        )
      ],
      measurements: [BodyMeasurement(id: 'body', date: now, weightKg: 75)],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(_MemoryRepository(data))
      ],
      child: MaterialApp(theme: arcTheme(), home: const ProgressScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EXERCISE FOCUS'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('EXERCISE FOCUS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Barbell Bench Press'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('LATEST SESSION'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(LineChart), findsWidgets);
    await tester.scrollUntilVisible(find.text('BODY WEIGHT'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('75 kg'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('75 kg'), findsWidgets);
  });

  testWidgets('Workout shows time and distance inputs for matching exercises',
      (tester) async {
    final data = seedData().copyWith(
        activeSession: WorkoutSession(
      id: 'active',
      name: 'Cardio',
      startedAt: DateTime.now(),
      exercises: const [
        ExerciseLog(
            id: 'timed', exerciseId: 'plank', sets: [LoggedSet(id: 'time')]),
        ExerciseLog(
            id: 'distance',
            exerciseId: 'run',
            sets: [LoggedSet(id: 'distance')]),
      ],
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(_MemoryRepository(data))
      ],
      child: MaterialApp(theme: arcTheme(), home: const WorkoutScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SECONDS'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('time-timed-primary')), '75');
    await tester.scrollUntilVisible(find.text('Treadmill Run').first, 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('KM'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('distance-distance-primary')), '2.5');
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WorkoutScreen)));
    final logs = container
        .read(appControllerProvider)
        .requireValue
        .activeSession!
        .exercises;
    expect(logs[0].sets.single.seconds, 75);
    expect(logs[1].sets.single.distanceM, 2500);
  });

  testWidgets('Home and Program expose the redesigned primary flows',
      (tester) async {
    final repository = _MemoryRepository(seedData());
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: arcTheme(), home: const TodayScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ready to train?'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);

    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: arcTheme(), home: const PlanScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your routines'), findsOneWidget);
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR SCHEDULE'), findsOneWidget);
  });
}

class _MemoryRepository implements AppRepository {
  _MemoryRepository(this.data);
  AppData data;
  @override
  Future<String> exportJson() async => data.encode();
  @override
  Future<void> importJson(String raw) async => data = AppData.decode(raw);
  @override
  Future<AppData?> load() async => data;
  @override
  Future<void> save(AppData value) async => data = value;
}
