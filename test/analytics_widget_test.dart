import 'package:arctrack/application/app_controller.dart';
import 'package:arctrack/data/app_repository.dart';
import 'package:arctrack/domain/models.dart';
import 'package:arctrack/ui/screens/progress_screen.dart';
import 'package:arctrack/ui/screens/plan_screen.dart';
import 'package:arctrack/ui/screens/today_screen.dart';
import 'package:arctrack/ui/screens/workout_screen.dart';
import 'package:arctrack/ui/theme.dart';
import 'package:arctrack/main.dart';
import 'package:arctrack/ui/screens/splash_screen.dart';
import 'package:arctrack/ui/screens/routine_insights.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ui_components/liquid_ui_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('glass screens avoid backdrop filters and optical rendering',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(seedData()))
    ], child: const ArcTrackApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ArcTrackApp)));
    for (final path in [
      '/today',
      '/workout',
      '/plan',
      '/progress',
      '/history'
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing, reason: path);
      for (final element in find.byType(LiquidGlassSurface).evaluate()) {
        final surface = element.widget as LiquidGlassSurface;
        final settings = surface.settings ?? LiquidGlassTheme.of(element);
        expect(settings.rendering, isNot(LiquidGlassRendering.automatic),
            reason: path);
        expect(settings.blur, 0, reason: path);
        expect(settings.shadowBlur, 0, reason: path);
      }
      expect(tester.binding.hasScheduledFrame, isFalse, reason: path);
      expect(tester.takeException(), isNull, reason: path);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup shows branding and then opens local data',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(seedData()))
    ], child: const ArcTrackApp()));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('OFFLINE BY DESIGN'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Ready to train?'), findsOneWidget);
  });

  testWidgets('assisted logging stores assistance and workout body weight',
      (tester) async {
    final data = seedData().copyWith(
        activeSession: WorkoutSession(
            id: 'assist',
            name: 'Pull',
            startedAt: DateTime.now(),
            exercises: const [
          ExerciseLog(
              id: 'log',
              exerciseId: 'assisted_pullup',
              sets: [LoggedSet(id: 'set')])
        ]));
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(data))
    ], child: MaterialApp(theme: arcTheme(), home: const WorkoutScreen())));
    await tester.pumpAndSettle();
    expect(find.text('ASSIST'), findsOneWidget);
    await tester.tap(find.text('Set body weight for this workout'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Body weight (kg)'), '80');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('set-assisted-primary')), '20');
    await tester.enterText(find.byKey(const ValueKey('set-reps')), '10');
    await tester.pump();
    await tester.tap(find.byTooltip('Log set'));
    await tester.pump();
    final value =
        ProviderScope.containerOf(tester.element(find.byType(WorkoutScreen)))
            .read(appControllerProvider)
            .requireValue;
    expect(value.activeSession!.bodyWeightKg, 80);
    expect(value.activeSession!.exercises.single.sets.single.weightKg, 20);
    expect(value.sessionVolume(value.activeSession!), 600);
    expect(find.text('600 kg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('routine filters and metrics render at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final data = seedData().copyWith(sessions: [
      WorkoutSession(
        id: 'routine-session',
        name: 'Push',
        templateId: 'push',
        startedAt: now.subtract(const Duration(minutes: 30)),
        completedAt: now,
        exercises: const [
          ExerciseLog(id: 'log', exerciseId: 'bench', sets: [
            LoggedSet(id: 'set', weightKg: 50, reps: 10, completed: true)
          ])
        ],
      )
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: arcTheme(),
        home: Scaffold(
            body: SingleChildScrollView(child: RoutineInsights(data: data)))));
    await tester.pumpAndSettle();
    expect(find.text('500 kg'), findsNWidgets(2));
    await tester.tap(find.text('Sets'));
    await tester.pumpAndSettle();
    expect(find.text('1 sets'), findsNWidgets(2));
    await tester.tap(find.text('Duration'));
    await tester.pumpAndSettle();
    expect(find.text('30.0 min'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'logging validates, copies previous values and restores deleted sets',
      (tester) async {
    final now = DateTime.now();
    final data = seedData().copyWith(
      sessions: [
        WorkoutSession(
            id: 'previous',
            name: 'Push',
            startedAt: now,
            completedAt: now,
            exercises: const [
              ExerciseLog(id: 'previous-log', exerciseId: 'bench', sets: [
                LoggedSet(id: 'old', weightKg: 50, reps: 5, completed: true)
              ])
            ])
      ],
      activeSession: WorkoutSession(
          id: 'active',
          name: 'Push',
          startedAt: now,
          exercises: const [
            ExerciseLog(
                id: 'active-log',
                exerciseId: 'bench',
                sets: [LoggedSet(id: 'new')])
          ]),
    );
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(data))
    ], child: MaterialApp(theme: arcTheme(), home: const WorkoutScreen())));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WorkoutScreen)));
    LoggedSet logged() => container
        .read(appControllerProvider)
        .requireValue
        .activeSession!
        .exercises
        .single
        .sets
        .single;
    await tester.tap(find.byTooltip('Log set'));
    await tester.pump();
    expect(logged().completed, isFalse);
    expect(find.text('Enter weight and reps before logging this set.'),
        findsOneWidget);
    await tester.tap(find.text('50 \u00d7 5'));
    await tester.pump();
    expect(logged().weightKg, 50);
    expect(find.widgetWithText(TextField, '50'), findsOneWidget);
    await tester.tap(find.byTooltip('Log set'));
    await tester.pump();
    expect(logged().completed, isTrue);
    expect(find.text('Skip'), findsOneWidget);
    final exerciseBeforeTick =
        tester.widget(find.byKey(const ValueKey('active-log')));
    await tester.pump(const Duration(seconds: 2));
    expect(
        identical(exerciseBeforeTick,
            tester.widget(find.byKey(const ValueKey('active-log')))),
        isTrue,
        reason: 'Rest ticks should not rebuild the exercise logging subtree');
    await tester.drag(
        find.byWidgetPredicate(
            (w) => w is Dismissible && w.key == const ValueKey('new')),
        const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
        container
            .read(appControllerProvider)
            .requireValue
            .activeSession!
            .exercises
            .single
            .sets,
        isEmpty);
    final undoMessage = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(undoMessage.persist, isFalse);
    expect(undoMessage.duration, const Duration(seconds: 4));
    expect(
        find.ancestor(
            of: find.widgetWithText(SnackBarAction, 'Undo'),
            matching: find.byType(LiquidGlassSurface)),
        findsOneWidget,
        reason: 'Undo belongs inside the package glass snackbar');
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(logged().weightKg, 50);
    expect(logged().completed, isTrue);
    await tester.tap(find.byTooltip('Set 1 details'));
    await tester.pumpAndSettle();
    expect(find.text('RPE: not set'), findsOneWidget);
    final effortSlider =
        tester.widget<LiquidGlassSlider>(find.byType(LiquidGlassSlider));
    expect(effortSlider.settings!.blur, 0);
    effortSlider.onChanged!(7.5);
    await tester.pump();
    expect(find.widgetWithText(TextField, '7.5'), findsOneWidget);
    expect(find.text('RPE: 7.5 / 10'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Notes (optional)'), 'Strong finish');
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();
    expect(logged().notes, 'Strong finish');
    expect(logged().rpe, 7.5);
    await tester.drag(
        find.byWidgetPredicate(
            (w) => w is Dismissible && w.key == const ValueKey('new')),
        const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

  testWidgets('Finish workout fits on a phone and its saved toast expires',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = seedData().copyWith(
        activeSession: WorkoutSession(
            id: 'finishing',
            name: 'Push',
            startedAt: DateTime.now(),
            exercises: const [
          ExerciseLog(id: 'log', exerciseId: 'bench', sets: [
            LoggedSet(id: 'done', weightKg: 50, reps: 8, completed: true),
          ])
        ]));
    await tester.pumpWidget(ProviderScope(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(data))
    ], child: const ArcTrackApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ArcTrackApp)));
    container.read(routerProvider).go('/workout');
    await tester.pumpAndSettle();
    final finish = find.byKey(const ValueKey('finish-workout'));
    expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
    expect(tester.getSize(finish).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).requireValue.activeSession,
        isNotNull);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).requireValue.activeSession,
        isNull);
    expect(
        container.read(appControllerProvider).requireValue.sessions.single.id,
        'finishing');
    expect(find.text('Workout saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Workout saved'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
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
    expect(find.byType(LiquidGlassMorph), findsOneWidget);
    final expandedHeight = tester.getSize(find.byType(LiquidGlassMorph)).height;
    await tester.tap(find.byTooltip('Minimize workout controls'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BackdropFilter), findsNothing,
        reason: 'The morph must stay filter-free during animation too');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LiquidGlassMorph)).height,
        lessThan(expandedHeight));
    expect(find.text('Start workout'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Expand workout controls'));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsOneWidget);
    expect(tester.takeException(), isNull);

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
