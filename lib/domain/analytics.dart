import 'models.dart';

enum TrendMetric { estimatedMax, heaviest, reps, volume, duration, distance }

enum TrendRange { month, threeMonths, sixMonths, all }

class TrendPoint {
  const TrendPoint(this.date, this.value, this.sessionId);
  final DateTime date;
  final double value;
  final String sessionId;
}

List<TrendMetric> metricsFor(Exercise exercise, List<WorkoutSession> sessions) {
  switch (exercise.kind) {
    case ExerciseKind.timed:
      return [TrendMetric.duration];
    case ExerciseKind.distance:
      return [TrendMetric.distance];
    case ExerciseKind.strength:
      return [
        TrendMetric.estimatedMax,
        TrendMetric.heaviest,
        TrendMetric.reps,
        TrendMetric.volume
      ];
    case ExerciseKind.bodyweight:
      final weighted = sessions.any((s) =>
          s.complete &&
          s.exercises.any((l) =>
              l.exerciseId == exercise.id &&
              l.sets.any((set) =>
                  set.completed &&
                  set.kind != SetKind.warmup &&
                  set.weightKg > 0)));
      return [
        TrendMetric.reps,
        if (weighted) TrendMetric.heaviest,
        if (weighted) TrendMetric.volume
      ];
  }
}

List<TrendPoint> exerciseTrend(List<WorkoutSession> sessions, String exerciseId,
    TrendMetric metric, TrendRange range, DateTime now) {
  final cutoff = switch (range) {
    TrendRange.month => _monthsAgo(now, 1),
    TrendRange.threeMonths => _monthsAgo(now, 3),
    TrendRange.sixMonths => _monthsAgo(now, 6),
    TrendRange.all => null,
  };
  final points = <TrendPoint>[];
  for (final session in sessions) {
    if (!session.complete ||
        (cutoff != null && session.startedAt.isBefore(cutoff)) ||
        session.startedAt.isAfter(now)) continue;
    final sets = session.exercises
        .where((l) => l.exerciseId == exerciseId)
        .expand((l) => l.sets)
        .where((s) => s.completed && s.kind != SetKind.warmup);
    final values = <double>[];
    for (final set in sets) {
      final value = switch (metric) {
        TrendMetric.estimatedMax => set.weightKg > 0 && set.reps > 0
            ? set.weightKg * (1 + set.reps / 30)
            : null,
        TrendMetric.heaviest => set.weightKg > 0 ? set.weightKg : null,
        TrendMetric.reps => set.reps > 0 ? set.reps.toDouble() : null,
        TrendMetric.volume =>
          set.weightKg > 0 && set.reps > 0 ? set.weightKg * set.reps : null,
        TrendMetric.duration => set.seconds > 0 ? set.seconds.toDouble() : null,
        TrendMetric.distance => set.distanceM > 0 ? set.distanceM : null,
      };
      if (value != null) values.add(value);
    }
    if (values.isEmpty) continue;
    final result = metric == TrendMetric.volume
        ? values.reduce((a, b) => a + b)
        : values.reduce((a, b) => a > b ? a : b);
    points.add(TrendPoint(session.startedAt, result, session.id));
  }
  points.sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.sessionId.compareTo(b.sessionId);
  });
  return points;
}

DateTime _monthsAgo(DateTime date, int months) {
  final first = DateTime(date.year, date.month - months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(
      first.year, first.month, date.day < lastDay ? date.day : lastDay);
}

class WeeklyTraining {
  const WeeklyTraining(this.start, this.workouts, this.workingSets);
  final DateTime start;
  final int workouts;
  final int workingSets;
}

class TrainingSummary {
  const TrainingSummary(this.workouts, this.previousWorkouts, this.workingSets,
      this.previousWorkingSets);
  final int workouts;
  final int previousWorkouts;
  final int workingSets;
  final int previousWorkingSets;
  double? get workoutChange => previousWorkouts == 0
      ? null
      : (workouts - previousWorkouts) / previousWorkouts * 100;
}

TrainingSummary trainingSummary(List<WorkoutSession> sessions, DateTime now) {
  final recentStart = now.subtract(const Duration(days: 28));
  final previousStart = now.subtract(const Duration(days: 56));
  final recent = sessions
      .where((s) =>
          s.complete &&
          !s.startedAt.isBefore(recentStart) &&
          !s.startedAt.isAfter(now))
      .toList();
  final previous = sessions
      .where((s) =>
          s.complete &&
          !s.startedAt.isBefore(previousStart) &&
          s.startedAt.isBefore(recentStart))
      .toList();
  return TrainingSummary(
      recent.length,
      previous.length,
      recent.fold(0, (sum, s) => sum + s.workingSets),
      previous.fold(0, (sum, s) => sum + s.workingSets));
}

List<WeeklyTraining> weeklyTraining(List<WorkoutSession> sessions, DateTime now,
    {int weeks = 6}) {
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  return List.generate(weeks, (index) {
    final start = monday.subtract(Duration(days: 7 * (weeks - index - 1)));
    final matching = sessions.where((s) =>
        s.complete &&
        !s.startedAt.isBefore(start) &&
        s.startedAt.isBefore(start.add(const Duration(days: 7))));
    return WeeklyTraining(start, matching.length,
        matching.fold(0, (sum, s) => sum + s.workingSets));
  });
}
