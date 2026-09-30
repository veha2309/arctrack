import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../application/app_controller.dart';
import '../../domain/analytics.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String? selectedId;
  TrendMetric? selectedMetric;
  TrendRange range = TrendRange.threeMonths;
  bool showSets = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights'), actions: [
        IconButton(
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.history),
            tooltip: 'Workout history'),
        IconButton(
            onPressed: async.value == null
                ? null
                : () => _measurement(context, ref, async.value!),
            icon: const Icon(Icons.add),
            tooltip: 'Log body weight')
      ]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => _body(data),
      ),
    );
  }

  Widget _body(AppData data) {
    final completed = data.sessions.where((s) => s.complete).toList();
    final weeks = weeklyTraining(completed, DateTime.now());
    final summary = trainingSummary(completed, DateTime.now());
    final volume = completed.fold<double>(0, (sum, s) => sum + s.volume);
    final records = _records(data);
    final available = data.exercises
        .where((e) => completed.any((s) => s.exercises.any((log) =>
            log.exerciseId == e.id &&
            log.sets
                .any((set) => set.completed && set.kind != SetKind.warmup))))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final recentSessions = [...completed]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final recentExerciseId = recentSessions
        .expand((s) => s.exercises)
        .where((log) =>
            log.sets.any((set) => set.completed && set.kind != SetKind.warmup))
        .map((log) => log.exerciseId)
        .firstOrNull;
    final exercise = available.where((e) => e.id == selectedId).firstOrNull ??
        available.where((e) => e.id == recentExerciseId).firstOrNull ??
        available.firstOrNull;
    final metrics =
        exercise == null ? <TrendMetric>[] : metricsFor(exercise, completed);
    final metric = metrics.contains(selectedMetric)
        ? selectedMetric!
        : metrics.firstOrNull;
    final points = exercise == null || metric == null
        ? <TrendPoint>[]
        : exerciseTrend(completed, exercise.id, metric, range, DateTime.now());
    final bodyPoints = [...data.measurements]
      ..sort((a, b) => a.date.compareTo(b.date));
    return ListView(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ArcPanel(
              color: ArcColors.raised,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Last 4 weeks', color: ArcColors.blue),
                    const SizedBox(height: 8),
                    Text('${summary.workouts} workouts',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(_trainingMessage(summary),
                        style: const TextStyle(
                            color: ArcColors.muted, height: 1.35)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _MiniStat(
                              '${summary.workingSets}', 'WORKING SETS')),
                      Expanded(
                          child: _MiniStat(
                              '${_streak(completed)}', 'WEEK STREAK')),
                      Expanded(
                          child: _MiniStat(
                              _compact(weightForDisplay(volume, data.useKg)),
                              'LIFETIME ${weightUnit(data.useKg).toUpperCase()}')),
                    ]),
                  ]))),
      const SectionHeader('Training rhythm'),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
                child: Text(
                    showSets
                        ? 'Working sets per week'
                        : 'Completed workouts per week',
                    style:
                        const TextStyle(color: ArcColors.muted, fontSize: 12))),
            TextButton(
                onPressed: () => setState(() => showSets = !showSets),
                child: Text(showSets ? 'Show workouts' : 'Show sets')),
          ])),
      SizedBox(
          height: 205,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _WeeklyChart(weeks, showSets: showSets))),
      const SectionHeader('Exercise focus'),
      if (exercise == null)
        const EmptyState(
            title: 'No exercise history',
            body: 'Complete a workout to see performance over time.')
      else ...[
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              key: ValueKey(exercise.id),
              initialValue: exercise.id,
              decoration: const InputDecoration(labelText: 'Exercise'),
              items: available
                  .map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (id) => setState(() {
                selectedId = id;
                selectedMetric = null;
              }),
            )),
        const SizedBox(height: 10),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<TrendMetric>(
              key: ValueKey('${exercise.id}-${metric?.name}'),
              initialValue: metric,
              decoration: const InputDecoration(labelText: 'Track'),
              items: metrics
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(_metricLabel(m))))
                  .toList(),
              onChanged: (m) => setState(() => selectedMetric = m),
            )),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
                spacing: 8,
                children: TrendRange.values
                    .map((r) => ChoiceChip(
                          label: Text(_rangeLabel(r)),
                          selected: r == range,
                          onSelected: (_) => setState(() => range = r),
                        ))
                    .toList())),
        if (points.isEmpty)
          const EmptyState(
              title: 'No values in this range',
              body: 'Choose a longer range or log a completed set.')
        else ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ArcPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Eyebrow('Latest session', color: ArcColors.blue),
                    const SizedBox(height: 8),
                    Text(_value(points.last.value, metric!, data.useKg),
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(_exerciseMessage(points),
                        style: const TextStyle(
                            color: ArcColors.muted, height: 1.35)),
                  ]))),
          SizedBox(
              height: 235,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 22, 0),
                  child: _TrendChart(
                      points: points,
                      display: (value) => _value(value, metric, data.useKg)))),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ExpansionTile(
                  title: const Text('Recent sessions'),
                  children: points.reversed
                      .take(5)
                      .map((point) => ListTile(
                          title: Text(_value(point.value, metric, data.useKg)),
                          subtitle:
                              Text(DateFormat('d MMM yyyy').format(point.date)),
                          dense: true))
                      .toList())),
        ],
      ],
      const SectionHeader('Personal records'),
      if (records.isEmpty)
        const EmptyState(
            title: 'No records yet',
            body: 'Complete weighted sets to establish personal records.')
      else
        ...records.take(6).map((record) => ListTile(
            title: Text(record.name),
            subtitle: Text(
                'Estimated 1RM · ${formatWeight(record.weight, data.useKg)} ${weightUnit(data.useKg)}'),
            trailing: Text(
                '${formatWeight(record.actual, data.useKg)} × ${record.reps}'))),
      const SectionHeader('Body weight'),
      if (bodyPoints.isEmpty)
        const EmptyState(
            title: 'No measurements', body: 'Log body weight to see the trend.')
      else ...[
        SizedBox(
            height: 205,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 22, 0),
                child: _TrendChart(
                    points: bodyPoints
                        .map((m) => TrendPoint(m.date, m.weightKg, m.id))
                        .toList(),
                    display: (v) =>
                        '${formatWeight(v, data.useKg)} ${weightUnit(data.useKg)}'))),
        ...bodyPoints.reversed.take(5).map((m) => ListTile(
            title: Text(
                '${formatWeight(m.weightKg, data.useKg)} ${weightUnit(data.useKg)}'),
            subtitle: Text(DateFormat('d MMM yyyy').format(m.date)),
            trailing: m.waistCm == null
                ? null
                : Text(
                    '${lengthForDisplay(m.waistCm!, data.useKg).toStringAsFixed(1)} ${lengthUnit(data.useKg)} waist'))),
      ],
      const SizedBox(height: 24),
    ]);
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.display});
  final List<TrendPoint> points;
  final String Function(double) display;
  @override
  Widget build(BuildContext context) {
    final minValue = points.map((p) => p.value).reduce(math.min);
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final padding = math.max(
        (maxValue - minValue) * .12, math.max(maxValue.abs() * .05, 1));
    final first = points.first.date.millisecondsSinceEpoch.toDouble();
    final last = points.last.date.millisecondsSinceEpoch.toDouble();
    final single = first == last;
    final spots = points
        .asMap()
        .entries
        .map((entry) => FlSpot(
            single
                ? entry.key.toDouble()
                : entry.value.date.millisecondsSinceEpoch.toDouble(),
            entry.value.value))
        .toList();
    return LineChart(LineChartData(
      minX: single ? -1 : first,
      maxX: single ? math.max(1, spots.length - 1).toDouble() : last,
      minY: math.max(0, minValue - padding),
      maxY: maxValue + padding,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: ArcColors.line, strokeWidth: 1)),
      titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: single ? 1 : (last - first) / 3,
                  getTitlesWidget: (value, _) {
                    final date = single
                        ? points.first.date
                        : DateTime.fromMillisecondsSinceEpoch(value.round());
                    return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('d MMM').format(date),
                            style: const TextStyle(
                                fontSize: 10, color: ArcColors.muted)));
                  }))),
      lineBarsData: [
        LineChartBarData(
            spots: spots,
            color: ArcColors.accent,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
                show: true, color: ArcColors.accent.withValues(alpha: .08)))
      ],
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                      '${DateFormat('d MMM yyyy').format(points[s.spotIndex].date)}\n${display(s.y)}',
                      const TextStyle(color: ArcColors.text)))
                  .toList())),
    ));
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart(this.weeks, {required this.showSets});
  final List<WeeklyTraining> weeks;
  final bool showSets;
  @override
  Widget build(BuildContext context) {
    final maximum = weeks.fold<int>(
        0, (m, w) => math.max(m, showSets ? w.workingSets : w.workouts));
    return BarChart(BarChartData(
      maxY: math.max(1, maximum).toDouble() * 1.2,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: ArcColors.line, strokeWidth: 1)),
      titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, _) => Text('${value.round()}',
                      style: const TextStyle(
                          color: ArcColors.muted, fontSize: 9)))),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 27,
                  getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          DateFormat('d MMM').format(
                              weeks[value.toInt().clamp(0, weeks.length - 1)]
                                  .start),
                          style: const TextStyle(
                              fontSize: 9, color: ArcColors.muted)))))),
      barGroups: weeks
          .asMap()
          .entries
          .map((entry) => BarChartGroupData(x: entry.key, barRods: [
                BarChartRodData(
                    toY: (showSets
                            ? entry.value.workingSets
                            : entry.value.workouts)
                        .toDouble(),
                    width: 22,
                    color: ArcColors.accent),
              ]))
          .toList(),
    ));
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: ArcColors.muted, fontSize: 9)),
      ]);
}

String _trainingMessage(TrainingSummary summary) {
  if (summary.workouts == 0)
    return 'No workouts in the last four weeks. Start a session to build momentum.';
  if (summary.previousWorkouts == 0)
    return 'Your first four-week baseline is taking shape. Keep logging to see a comparison.';
  final change = summary.workoutChange!;
  if (change <= -25)
    return 'You trained less often than the prior four weeks. A regular session this week can rebuild consistency.';
  if (change >= 25)
    return 'You trained more often than the prior four weeks. Review exercise trends to see how performance followed.';
  return 'Your workout frequency is steady compared with the prior four weeks.';
}

String _exerciseMessage(List<TrendPoint> points) {
  if (points.length == 1)
    return 'One completed session in this range. Log another to see a trend.';
  final first = points.first.value;
  final last = points.last.value;
  if (first <= 0) return '${points.length} completed sessions in this range.';
  final change = (last - first) / first * 100;
  if (change.abs() < 1)
    return 'Holding steady across ${points.length} sessions in this range.';
  return '${change > 0 ? 'Up' : 'Down'} ${change.abs().toStringAsFixed(1)}% from the first session in this range.';
}

String _metricLabel(TrendMetric metric) => switch (metric) {
      TrendMetric.estimatedMax => 'Estimated 1RM',
      TrendMetric.heaviest => 'Heaviest set',
      TrendMetric.reps => 'Most reps',
      TrendMetric.volume => 'Session volume',
      TrendMetric.duration => 'Longest set',
      TrendMetric.distance => 'Farthest set',
    };
String _rangeLabel(TrendRange range) => switch (range) {
      TrendRange.month => '1M',
      TrendRange.threeMonths => '3M',
      TrendRange.sixMonths => '6M',
      TrendRange.all => 'All',
    };
String _value(double value, TrendMetric metric, bool useKg) => switch (metric) {
      TrendMetric.estimatedMax ||
      TrendMetric.heaviest ||
      TrendMetric.volume =>
        '${formatWeight(value, useKg)} ${weightUnit(useKg)}',
      TrendMetric.reps => '${value.round()} reps',
      TrendMetric.duration => '${value.round()} s',
      TrendMetric.distance =>
        '${distanceForDisplay(value, useKg).toStringAsFixed(2)} ${distanceUnit(useKg)}',
    };
String _compact(double value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(1)}m'
    : value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : '${value.round()}';

class _Record {
  const _Record(this.name, this.weight, this.actual, this.reps);
  final String name;
  final double weight;
  final double actual;
  final int reps;
}

List<_Record> _records(AppData data) {
  final records = <String, _Record>{};
  for (final session in data.sessions.where((s) => s.complete)) {
    for (final log in session.exercises) {
      final exercise =
          data.exercises.where((e) => e.id == log.exerciseId).firstOrNull;
      if (exercise == null || exercise.kind != ExerciseKind.strength) continue;
      for (final set in log.sets.where((s) =>
          s.completed &&
          s.kind != SetKind.warmup &&
          s.weightKg > 0 &&
          s.reps > 0)) {
        final estimate = set.weightKg * (1 + set.reps / 30);
        final previous = records[log.exerciseId];
        if (previous == null || estimate > previous.weight) {
          records[log.exerciseId] =
              _Record(exercise.name, estimate, set.weightKg, set.reps);
        }
      }
    }
  }
  return records.values.toList()..sort((a, b) => b.weight.compareTo(a.weight));
}

int _streak(List<WorkoutSession> sessions) {
  final weeks = sessions.map((s) {
    final date = s.startedAt;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }).toSet();
  var cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day)
      .subtract(Duration(days: cursor.weekday - 1));
  if (!weeks.contains(cursor))
    cursor = cursor.subtract(const Duration(days: 7));
  var count = 0;
  while (weeks.contains(cursor)) {
    count++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return count;
}

Future<void> _measurement(
    BuildContext context, WidgetRef ref, AppData data) async {
  final weight = TextEditingController();
  final waist = TextEditingController();
  await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('Body measurement'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: weight,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Weight (${weightUnit(data.useKg)})')),
              const SizedBox(height: 10),
              TextField(
                  controller: waist,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText:
                          'Waist (${lengthUnit(data.useKg)}, optional)')),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () {
                    final entered = double.tryParse(weight.text);
                    if (entered == null || entered <= 0) return;
                    final enteredWaist = double.tryParse(waist.text);
                    ref.read(appControllerProvider.notifier).addMeasurement(
                        weightToKilograms(entered, data.useKg),
                        enteredWaist == null
                            ? null
                            : lengthToCentimeters(enteredWaist, data.useKg));
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save')),
            ],
          ));
  weight.dispose();
  waist.dispose();
}
