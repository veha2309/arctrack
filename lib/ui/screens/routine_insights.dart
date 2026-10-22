import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/analytics.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class RoutineInsights extends StatefulWidget {
  const RoutineInsights({super.key, required this.data});
  final AppData data;
  @override
  State<RoutineInsights> createState() => _RoutineInsightsState();
}

class _RoutineInsightsState extends State<RoutineInsights> {
  TrendRange range = TrendRange.threeMonths;
  RoutineMetric metric = RoutineMetric.volume;
  String? selected;
  String _key(RoutineAnalysis r) =>
      r.id == null ? 'unplanned' : 'routine:${r.id}';

  String _value(double value) => switch (metric) {
        RoutineMetric.volume =>
          '${formatWeight(value, widget.data.useKg)} ${weightUnit(widget.data.useKg)}',
        RoutineMetric.sets =>
          '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} sets',
        RoutineMetric.reps =>
          '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} reps',
        RoutineMetric.minutes => '${value.toStringAsFixed(1)} min',
      };

  @override
  Widget build(BuildContext context) {
    final routines = routineAnalyses(widget.data, range, DateTime.now());
    final routine = routines.where((r) => _key(r) == selected).firstOrNull ??
        routines.firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Routine analysis'),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ArcPanel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Your plan, in perspective', color: ArcColors.blue),
              const SizedBox(height: 8),
              const Text('See what each routine delivers.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'Compare completed sessions from the same workout plan. Warmups are excluded from workload.',
                  style: TextStyle(color: ArcColors.muted)),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 6,
                  children: TrendRange.values
                      .map((r) => ChoiceChip(
                            showCheckmark: false,
                            label: Text(switch (r) {
                              TrendRange.month => '1M',
                              TrendRange.threeMonths => '3M',
                              TrendRange.sixMonths => '6M',
                              TrendRange.all => 'All'
                            }),
                            selected: range == r,
                            onSelected: (_) => setState(() => range = r),
                          ))
                      .toList()),
              if (routine == null)
                const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                        'Create a routine in Program to start tracking its progress.'))
              else ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    key: ValueKey(_key(routine)),
                    initialValue: _key(routine),
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Workout plan'),
                    items: routines
                        .map((r) => DropdownMenuItem(
                            value: _key(r),
                            child: Text('${r.name} · ${r.sessions.length}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (id) => setState(() => selected = id)),
                const SizedBox(height: 12),
                Wrap(
                    spacing: 6,
                    children: RoutineMetric.values
                        .map((m) => ChoiceChip(
                              showCheckmark: false,
                              label: Text(switch (m) {
                                RoutineMetric.volume => 'Volume',
                                RoutineMetric.sets => 'Sets',
                                RoutineMetric.reps => 'Reps',
                                RoutineMetric.minutes => 'Duration'
                              }),
                              selected: metric == m,
                              onSelected: (_) => setState(() => metric = m),
                            ))
                        .toList()),
                if (routine.sessions.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                          'No completed sessions in this range. Try a longer range or finish this routine.',
                          style: TextStyle(color: ArcColors.muted)))
                else ...[
                  const SizedBox(height: 18),
                  Row(children: [
                    Metric(
                        label: 'LATEST',
                        value: _value(routineValue(
                            routine.sessions.last, metric,
                            data: widget.data))),
                    Metric(
                        label: 'SESSION AVERAGE',
                        value: _value(routine.average(metric))),
                  ]),
                  Text(
                      routine.change(metric) == null
                          ? 'Log at least two sessions with a nonzero baseline to compare.'
                          : '${routine.change(metric)! >= 0 ? '+' : ''}${routine.change(metric)!.toStringAsFixed(1)}% vs previous session',
                      style: const TextStyle(
                          color: ArcColors.blue, fontWeight: FontWeight.w700)),
                  if (metric == RoutineMetric.minutes)
                    const Text(
                        'Elapsed workout time, including rest. Longer is not necessarily better.',
                        style: TextStyle(color: ArcColors.muted, fontSize: 12)),
                  if (metric == RoutineMetric.volume)
                    const Text(
                        'Volume = weight × reps. Changes in exercises or set count affect this comparison.',
                        style: TextStyle(color: ArcColors.muted, fontSize: 12)),
                  if (metric == RoutineMetric.volume &&
                      routine.sessions.any((s) => s.exercises.any((log) =>
                          widget.data.exercises.any((e) =>
                              e.id == log.exerciseId &&
                              e.kind == ExerciseKind.assisted))))
                    const Text(
                        'Assisted volume uses body weight minus assistance. Sets without body weight are excluded.',
                        style: TextStyle(color: ArcColors.muted, fontSize: 12)),
                  const SizedBox(height: 20),
                  SizedBox(
                      height: 180,
                      child: _RoutineChart(
                          points: routine.trend(metric), display: _value)),
                  const SizedBox(height: 18),
                  const Eyebrow('Muscle distribution · working sets'),
                  const SizedBox(height: 12),
                  ..._muscles(routine),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Session breakdown'),
                      children: routine.sessions.reversed
                          .take(8)
                          .map((s) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(DateFormat('d MMM yyyy')
                                    .format(s.startedAt)),
                                subtitle: Text(
                                    '${s.workingSets} working sets · ${s.exercises.where((e) => e.sets.any((s) => s.completed)).length} exercises'),
                                trailing: Text(_value(routineValue(s, metric,
                                    data: widget.data))),
                              ))
                          .toList()),
                ],
              ],
            ]),
          )),
    ]);
  }

  List<Widget> _muscles(RoutineAnalysis routine) {
    final muscles = muscleWorkingSets(widget.data, routine.sessions);
    final total = muscles.values.fold(0, (a, b) => a + b);
    return muscles.entries
        .map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(e.key)),
                Text('${e.value} · ${(e.value / total * 100).round()}%',
                    style:
                        const TextStyle(color: ArcColors.muted, fontSize: 12))
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: e.value / total,
                      minHeight: 6,
                      color: ArcColors.blue,
                      backgroundColor: ArcColors.raised)),
            ])))
        .toList();
  }
}

class _RoutineChart extends StatelessWidget {
  const _RoutineChart({required this.points, required this.display});
  final List<TrendPoint> points;
  final String Function(double) display;
  @override
  Widget build(BuildContext context) {
    final maximum = points.fold(0.0, (m, p) => math.max(m, p.value));
    return LineChart(LineChartData(
      minX: points.length == 1 ? -1 : 0,
      maxX: math.max(1, points.length - 1).toDouble(),
      minY: 0,
      maxY: math.max(1, maximum * 1.2),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: ArcColors.line)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                interval: math.max(1, (points.length / 3).ceil()).toDouble(),
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= points.length ||
                      value != index.toDouble()) return const SizedBox.shrink();
                  return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          DateFormat('d MMM').format(points[index].date),
                          style: const TextStyle(
                              color: ArcColors.muted, fontSize: 10)));
                })),
      ),
      lineBarsData: [
        LineChartBarData(
            spots: points
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            color: ArcColors.blue,
            barWidth: 3,
            belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ArcColors.blue.withValues(alpha: .22),
                      ArcColors.blue.withValues(alpha: 0)
                    ])))
      ],
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                      '${DateFormat('d MMM').format(points[s.spotIndex].date)}\n${display(s.y)}',
                      const TextStyle(color: ArcColors.text)))
                  .toList())),
    ));
  }
}
