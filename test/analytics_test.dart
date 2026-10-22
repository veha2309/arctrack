import 'package:arctrack/domain/analytics.dart';
import 'package:arctrack/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 30);
  WorkoutSession session(String id, DateTime date, List<LoggedSet> sets,
          {bool complete = true}) =>
      WorkoutSession(
        id: id,
        name: 'Training',
        startedAt: date,
        completedAt: complete ? date : null,
        exercises: [ExerciseLog(id: 'log-$id', exerciseId: 'lift', sets: sets)],
      );

  test('routine analysis preserves stable identities and filters history', () {
    WorkoutSession workout(String id, String? routine, DateTime date,
            {bool complete = true}) =>
        WorkoutSession(
          id: id,
          name: 'Same name',
          templateId: routine,
          startedAt: date,
          completedAt: complete ? date.add(const Duration(minutes: 30)) : null,
          exercises: const [
            ExerciseLog(id: 'log', exerciseId: 'lift', sets: [
              LoggedSet(id: 'working', weightKg: 50, reps: 10, completed: true),
              LoggedSet(
                  id: 'warmup',
                  weightKg: 100,
                  reps: 10,
                  completed: true,
                  kind: SetKind.warmup),
              LoggedSet(id: 'pending', weightKg: 100, reps: 10),
            ])
          ],
        );
    final data = AppData(
        exercises: const [Exercise(id: 'lift', name: 'Lift', muscle: 'Back')],
        templates: const [
          WorkoutTemplate(id: 'a', name: 'Renamed', exercises: [])
        ],
        rotation: const [],
        rotationIndex: 0,
        measurements: const [],
        checkIns: const [],
        sessions: [
          workout('a1', 'a', DateTime(2026, 9, 1)),
          workout('b1', 'deleted', DateTime(2026, 9, 2)),
          workout('free', null, DateTime(2026, 9, 3)),
          workout('old', 'a', DateTime(2026, 1, 1)),
          workout('future', 'a', DateTime(2026, 10, 1)),
          workout('active', 'a', DateTime(2026, 9, 4), complete: false),
        ]);
    final routines = routineAnalyses(data, TrendRange.month, now);
    expect(routines, hasLength(3));
    final renamed = routines.singleWhere((r) => r.id == 'a');
    expect(renamed.name, 'Renamed');
    expect(renamed.sessions.map((s) => s.id), ['a1']);
    expect(renamed.average(RoutineMetric.volume), 500);
    expect(renamed.average(RoutineMetric.minutes), 30);
    expect(renamed.average(RoutineMetric.sets), 1);
    expect(renamed.average(RoutineMetric.reps), 10);
    expect(
        muscleWorkingSets(
            data, sessionsInRange(data.sessions, TrendRange.month, now)),
        {'Back': 3});
    expect(routines.singleWhere((r) => r.id == 'deleted').name, 'Same name');
    expect(
        routines.singleWhere((r) => r.id == null).name, 'Unplanned workouts');
  });

  test('routine change uses previous session and handles zero baselines', () {
    final first = session('one', DateTime(2026, 9, 1),
        const [LoggedSet(id: '1', weightKg: 50, reps: 10, completed: true)]);
    final second = session('two', DateTime(2026, 9, 2),
        const [LoggedSet(id: '2', weightKg: 60, reps: 10, completed: true)]);
    final routine = RoutineAnalysis('r', 'Routine', [first, second]);
    expect(routine.change(RoutineMetric.volume), 20);
    expect(routine.average(RoutineMetric.volume), 550);
    expect(
        RoutineAnalysis('r', 'Routine', [first]).change(RoutineMetric.volume),
        isNull);
    expect(RoutineAnalysis('r', 'Routine', []).average(RoutineMetric.sets), 0);
    expect(
        RoutineAnalysis('r', 'Routine', [session('zero', now, []), second])
            .change(RoutineMetric.volume),
        isNull);
  });

  test(
      'assisted loads subtract assistance, preserve snapshots and omit missing body weight',
      () {
    const exercise = Exercise(
        id: 'assist',
        name: 'Assisted Pull-up',
        muscle: 'Back',
        kind: ExerciseKind.assisted);
    WorkoutSession workout(String id, double? body, double assistance) =>
        WorkoutSession(
            id: id,
            name: 'Pull',
            templateId: 'pull',
            startedAt: now,
            completedAt: now,
            bodyWeightKg: body,
            exercises: [
              ExerciseLog(id: 'log', exerciseId: 'assist', sets: [
                LoggedSet(
                    id: 'set', weightKg: assistance, reps: 10, completed: true)
              ])
            ]);
    final first = workout('1', 80, 20);
    final second = workout('2', 80, 10);
    final data = AppData(
        exercises: const [exercise],
        templates: const [],
        rotation: const [],
        rotationIndex: 0,
        sessions: [first, second],
        measurements: const [],
        checkIns: const []);
    expect(data.sessionVolume(first), 600);
    expect(data.sessionVolume(second), 700);
    expect(data.sessionVolume(workout('zero', 80, 0)), 800);
    expect(data.sessionVolume(workout('over', 80, 100)), 0);
    expect(data.sessionVolume(workout('missing', null, 20)), 0);
    expect(
        exerciseTrend([
          first,
          second
        ], 'assist', TrendMetric.assistance, TrendRange.all, now, data: data)
            .map((p) => p.value),
        [20, 10]);
    expect(
        exerciseTrend([
          first
        ], 'assist', TrendMetric.effectiveLoad, TrendRange.all, now, data: data)
            .single
            .value,
        60);
    expect(
        exerciseTrend([workout('missing', null, 20)], 'assist',
            TrendMetric.effectiveLoad, TrendRange.all, now,
            data: data),
        isEmpty);
    final decoded = AppData.decode(data.encode());
    expect(decoded.sessions.first.bodyWeightKg, 80);
    expect(decoded.exercises.single.kind, ExerciseKind.assisted);
    final changed = data.copyWith(measurements: [
      BodyMeasurement(
          id: 'later', date: now.add(const Duration(days: 1)), weightKg: 90)
    ]);
    expect(changed.sessionVolume(first), 600);
    expect(changed.sessionVolume(workout('missing', null, 20)), 0);
    final prior = data.copyWith(measurements: [
      BodyMeasurement(
          id: 'prior',
          date: now.subtract(const Duration(days: 1)),
          weightKg: 75)
    ]);
    expect(prior.sessionVolume(workout('legacy', null, 20)), 550);
    expect(
        routineAnalyses(data, TrendRange.all, now)
            .single
            .average(RoutineMetric.volume),
        650);
  });

  test('strength trends sort, filter and aggregate completed working sets', () {
    final sessions = [
      session('new', DateTime(2026, 9, 20), [
        const LoggedSet(id: 'a', weightKg: 50, reps: 5, completed: true),
        const LoggedSet(id: 'b', weightKg: 40, reps: 10, completed: true),
        const LoggedSet(
            id: 'c',
            weightKg: 100,
            reps: 10,
            completed: true,
            kind: SetKind.warmup),
        const LoggedSet(id: 'd', weightKg: 200, reps: 10),
      ]),
      session('old', DateTime(2026, 5, 20), [
        const LoggedSet(id: 'e', weightKg: 30, reps: 5, completed: true),
      ]),
      session(
          'unfinished',
          DateTime(2026, 9, 25),
          [
            const LoggedSet(id: 'f', weightKg: 200, reps: 10, completed: true),
          ],
          complete: false),
    ];
    final all = exerciseTrend(
        sessions, 'lift', TrendMetric.heaviest, TrendRange.all, now);
    expect(all.map((p) => p.sessionId), ['old', 'new']);
    expect(
        exerciseTrend(sessions, 'lift', TrendMetric.volume,
                TrendRange.threeMonths, now)
            .single
            .value,
        650);
    expect(
        exerciseTrend(sessions, 'lift', TrendMetric.estimatedMax,
                TrendRange.threeMonths, now)
            .single
            .value,
        closeTo(58.33, .01));
    expect(
        exerciseTrend(
                sessions, 'lift', TrendMetric.heaviest, TrendRange.month, now)
            .length,
        1);
  });

  test('timed and distance trends omit missing values', () {
    final sessions = [
      session('one', DateTime(2026, 9, 20), [
        const LoggedSet(
            id: 'a', seconds: 60, distanceM: 1609.344, completed: true),
        const LoggedSet(id: 'b', seconds: 90, distanceM: 2000, completed: true),
      ])
    ];
    expect(
        exerciseTrend(
                sessions, 'lift', TrendMetric.duration, TrendRange.all, now)
            .single
            .value,
        90);
    expect(
        exerciseTrend(
                sessions, 'lift', TrendMetric.distance, TrendRange.all, now)
            .single
            .value,
        2000);
    expect(
        exerciseTrend(sessions, 'lift', TrendMetric.reps, TrendRange.all, now),
        isEmpty);
  });

  test('weekly totals include completed workouts only', () {
    final sessions = [
      session('one', DateTime(2026, 9, 28), [
        const LoggedSet(id: 'a', completed: true),
        const LoggedSet(id: 'b', completed: true, kind: SetKind.warmup),
      ]),
      session(
          'two',
          DateTime(2026, 9, 29),
          [
            const LoggedSet(id: 'c', completed: true),
          ],
          complete: false),
    ];
    final week = weeklyTraining(sessions, now).last;
    expect(week.workouts, 1);
    expect(week.workingSets, 1);
  });

  test('bodyweight metric exposes added weight only when logged', () {
    const exercise = Exercise(
        id: 'lift',
        name: 'Pull-up',
        muscle: 'Back',
        kind: ExerciseKind.bodyweight);
    expect(metricsFor(exercise, []), [TrendMetric.reps]);
    final sessions = [
      session('one', DateTime(2026, 9, 20), [
        const LoggedSet(id: 'a', weightKg: 10, reps: 5, completed: true),
      ])
    ];
    expect(metricsFor(exercise, sessions), contains(TrendMetric.heaviest));
  });

  test('distance display conversion round trips for kilometers and miles', () {
    expect(distanceForDisplay(1609.344, false), closeTo(1, 0.000001));
    expect(distanceToMeters(distanceForDisplay(2500, true), true),
        closeTo(2500, 0.000001));
    expect(distanceToMeters(distanceForDisplay(2500, false), false),
        closeTo(2500, 0.000001));
  });

  test('four-week summary compares equal windows and excludes active workouts',
      () {
    final sessions = [
      session('recent', DateTime(2026, 9, 20), [
        const LoggedSet(id: 'a', completed: true),
      ]),
      session('previous', DateTime(2026, 8, 20), [
        const LoggedSet(id: 'b', completed: true),
        const LoggedSet(id: 'c', completed: true),
      ]),
      session(
          'active',
          DateTime(2026, 9, 25),
          [
            const LoggedSet(id: 'd', completed: true),
          ],
          complete: false),
    ];
    final summary = trainingSummary(sessions, now);
    expect(summary.workouts, 1);
    expect(summary.previousWorkouts, 1);
    expect(summary.workingSets, 1);
    expect(summary.previousWorkingSets, 2);
    expect(summary.workoutChange, 0);
  });
}
