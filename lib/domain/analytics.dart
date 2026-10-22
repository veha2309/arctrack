import 'models.dart';

enum TrendMetric {
  estimatedMax,
  heaviest,
  reps,
  volume,
  duration,
  distance,
  assistance,
  effectiveLoad
}

enum TrendRange { month, threeMonths, sixMonths, all }

class TrendPoint {
  const TrendPoint(this.date, this.value, this.sessionId);
  final DateTime date;
  final double value;
  final String sessionId;
}

List<TrendMetric> metricsFor(Exercise exercise, List<WorkoutSession> sessions) {
  switch (exercise.kind) {
    case ExerciseKind.assisted:
      return [
        TrendMetric.assistance,
        TrendMetric.reps,
        TrendMetric.effectiveLoad,
        TrendMetric.volume
      ];
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
    TrendMetric metric, TrendRange range, DateTime now,
    {AppData? data}) {
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
    final log =
        session.exercises.where((l) => l.exerciseId == exerciseId).firstOrNull;
    final sets = session.exercises
        .where((l) => l.exerciseId == exerciseId)
        .expand((l) => l.sets)
        .where((s) => s.completed && s.kind != SetKind.warmup);
    final values = <double>[];
    for (final set in sets) {
      final load = data != null && log != null
          ? data.setLoad(session, log, set)
          : set.weightKg;
      final value = switch (metric) {
        TrendMetric.assistance => set.reps > 0 ? set.weightKg : null,
        TrendMetric.effectiveLoad => set.reps > 0 && data != null ? load : null,
        TrendMetric.estimatedMax => set.weightKg > 0 && set.reps > 0
            ? set.weightKg * (1 + set.reps / 30)
            : null,
        TrendMetric.heaviest => set.weightKg > 0 ? set.weightKg : null,
        TrendMetric.reps => set.reps > 0 ? set.reps.toDouble() : null,
        TrendMetric.volume =>
          load != null && load > 0 && set.reps > 0 ? load * set.reps : null,
        TrendMetric.duration => set.seconds > 0 ? set.seconds.toDouble() : null,
        TrendMetric.distance => set.distanceM > 0 ? set.distanceM : null,
      };
      if (value != null) values.add(value);
    }
    if (values.isEmpty) continue;
    final result = metric == TrendMetric.volume
        ? values.reduce((a, b) => a + b)
        : metric == TrendMetric.assistance
            ? values.reduce((a, b) => a < b ? a : b)
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
        s.startedAt.isBefore(start.add(const Duration(days: 7))) &&
        !s.startedAt.isAfter(now));
    return WeeklyTraining(start, matching.length,
        matching.fold(0, (sum, s) => sum + s.workingSets));
  });
}

/// Completed history in a calendar range, excluding future sessions.
List<WorkoutSession> sessionsInRange(
    List<WorkoutSession> sessions, TrendRange range, DateTime now) {
  final cutoff = switch (range) {
    TrendRange.month => _monthsAgo(now, 1),
    TrendRange.threeMonths => _monthsAgo(now, 3),
    TrendRange.sixMonths => _monthsAgo(now, 6),
    TrendRange.all => null,
  };
  return sessions
      .where((s) =>
          s.complete &&
          !s.startedAt.isAfter(now) &&
          (cutoff == null || !s.startedAt.isBefore(cutoff)))
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
}

enum RoutineMetric { volume, sets, reps, minutes }

/// Workload uses completed non-warmup sets consistently across all views.
double routineValue(WorkoutSession session, RoutineMetric metric,
    {AppData? data}) {
  final sets = session.exercises
      .expand((e) => e.sets)
      .where((s) => s.completed && s.kind != SetKind.warmup);
  return switch (metric) {
    RoutineMetric.volume => data?.sessionVolume(session) ??
        sets.fold(0.0, (sum, s) => sum + s.weightKg * s.reps),
    RoutineMetric.sets => sets.length.toDouble(),
    RoutineMetric.reps => sets.fold(0.0, (sum, s) => sum + s.reps),
    RoutineMetric.minutes => session.completedAt == null
        ? 0
        : session.completedAt!
                .difference(session.startedAt)
                .inSeconds
                .clamp(0, 2147483647) /
            60,
  };
}

class RoutineAnalysis {
  const RoutineAnalysis(this.id, this.name, this.sessions, {this.data});
  final AppData? data;
  final String? id;
  final String name;
  final List<WorkoutSession> sessions;
  double average(RoutineMetric metric) => sessions.isEmpty
      ? 0
      : sessions.fold(
              0.0, (sum, s) => sum + routineValue(s, metric, data: data)) /
          sessions.length;
  double? change(RoutineMetric metric) {
    if (sessions.length < 2) return null;
    final previous =
        routineValue(sessions[sessions.length - 2], metric, data: data);
    return previous <= 0
        ? null
        : (routineValue(sessions.last, metric, data: data) - previous) /
            previous *
            100;
  }

  List<TrendPoint> trend(RoutineMetric metric) => sessions
      .map((s) =>
          TrendPoint(s.startedAt, routineValue(s, metric, data: data), s.id))
      .toList();
}

List<RoutineAnalysis> routineAnalyses(
    AppData data, TrendRange range, DateTime now) {
  final history = sessionsInRange(data.sessions, range, now);
  final names = {
    for (final t in data.templates.where((t) => !t.isRest)) t.id: t.name
  };
  // Retain deleted routines by their stable ID, even if two names are identical.
  for (final s in history) {
    if (s.templateId != null) names.putIfAbsent(s.templateId!, () => s.name);
  }
  return [
    for (final entry in names.entries)
      RoutineAnalysis(entry.key, entry.value,
          history.where((s) => s.templateId == entry.key).toList(),
          data: data),
    if (history.any((s) => s.templateId == null))
      RoutineAnalysis(null, 'Unplanned workouts',
          history.where((s) => s.templateId == null).toList(),
          data: data),
  ]..sort((a, b) {
      final count = b.sessions.length.compareTo(a.sessions.length);
      return count == 0 ? a.name.compareTo(b.name) : count;
    });
}

Map<String, int> muscleWorkingSets(
    AppData data, List<WorkoutSession> sessions) {
  final muscles = {for (final e in data.exercises) e.id: e.muscle};
  final totals = <String, int>{};
  for (final s in sessions.where((s) => s.complete)) {
    for (final log in s.exercises) {
      final count =
          log.sets.where((s) => s.completed && s.kind != SetKind.warmup).length;
      if (count == 0) continue;
      final muscle = muscles[log.exerciseId] ?? 'Other';
      totals.update(muscle, (value) => value + count, ifAbsent: () => count);
    }
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}
