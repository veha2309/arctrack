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
