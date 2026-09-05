import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Progress'), actions: [
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
            data: (data) {
              final volume =
                  data.sessions.fold<double>(0, (a, s) => a + s.volume);
              final prs = _records(data);
              final streak = _streak(data);
              return ListView(children: [
                const SectionHeader('Training'),
                Container(
                    decoration: const BoxDecoration(
                        border: Border.symmetric(
                            horizontal: BorderSide(color: ArcColors.line))),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Metric(
                          label: 'WORKOUTS', value: '${data.sessions.length}'),
                      Metric(
                          label: 'TOTAL VOLUME',
                          value: _compact(weightForDisplay(volume, data.useKg)),
                          detail: weightUnit(data.useKg)),
                      Metric(label: 'STREAK', value: '$streak', detail: 'weeks')
                    ])),
                const SectionHeader('Weekly workload'),
                SizedBox(
                    height: 190,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 22, 0),
                        child: _WorkloadChart(data.sessions))),
                const SectionHeader('Personal records'),
                if (prs.isEmpty)
                  const EmptyState(
                      title: 'No records yet',
                      body:
                          'Complete weighted sets to establish personal records.')
                else
                  ...prs.take(6).map((r) => Column(children: [
                        ListTile(
                            title: Text(r.name),
                            subtitle: Text(
                                'Estimated 1RM · ${formatWeight(r.weight, data.useKg)} ${weightUnit(data.useKg)}'),
                            trailing: Text(
                                '${formatWeight(r.actual, data.useKg)} × ${r.reps}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        const Divider(height: 1, indent: 16)
                      ])),
                const SectionHeader('Body weight'),
                if (data.measurements.isEmpty)
                  const EmptyState(
                      title: 'No measurements',
                      body: 'Log body weight to see the trend.')
                else
                  ...data.measurements.take(8).map((m) => Column(children: [
                        ListTile(
                            title: Text(
                                '${formatWeight(m.weightKg, data.useKg)} ${weightUnit(data.useKg)}'),
                            subtitle:
                                Text(DateFormat('d MMM yyyy').format(m.date)),
                            trailing: m.waistCm == null
                                ? null
                                : Text(
                                    '${lengthForDisplay(m.waistCm!, data.useKg).toStringAsFixed(1)} ${lengthUnit(data.useKg)} waist')),
                        const Divider(height: 1, indent: 16)
                      ])),
                const SizedBox(height: 24),
              ]);
            }));
  }
}

class _WorkloadChart extends StatelessWidget {
  const _WorkloadChart(this.sessions);
  final List<WorkoutSession> sessions;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = List.generate(6, (i) {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: (5 - i) * 7 + now.weekday - 1));
      return sessions
          .where((s) =>
              !s.startedAt.isBefore(start) &&
              s.startedAt.isBefore(start.add(const Duration(days: 7))))
          .fold<int>(0, (a, s) => a + s.workingSets);
    });
    final maxY = math.max(10, values.fold<int>(0, math.max) + 5).toDouble();
    return BarChart(BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                            v.toInt() == 5 ? 'THIS WEEK' : 'W${v.toInt() + 1}',
                            style: const TextStyle(
                                color: ArcColors.muted, fontSize: 9)))))),
        barGroups: values
            .asMap()
            .entries
            .map((e) => BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                      toY: e.value.toDouble(),
                      width: 18,
                      color: e.key == 5 ? ArcColors.accent : ArcColors.muted,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(2)))
                ]))
            .toList(),
        barTouchData: BarTouchData(enabled: true)));
  }
}

class _Record {
  const _Record(this.name, this.weight, this.actual, this.reps);
  final String name;
  final double weight;
  final double actual;
  final int reps;
}

List<_Record> _records(AppData data) {
  final map = <String, _Record>{};
  for (final session in data.sessions) {
    for (final log in session.exercises) {
      final name = data.exercises
              .where((e) => e.id == log.exerciseId)
              .firstOrNull
              ?.name ??
          log.exerciseId;
      for (final set in log.sets
          .where((s) => s.completed && s.weightKg > 0 && s.reps > 0)) {
        final estimate = set.weightKg * (1 + set.reps / 30);
        final old = map[log.exerciseId];
        if (old == null || estimate > old.weight)
          map[log.exerciseId] = _Record(name, estimate, set.weightKg, set.reps);
      }
    }
  }
  final out = map.values.toList()..sort((a, b) => b.weight.compareTo(a.weight));
  return out;
}

int _streak(AppData data) {
  if (data.sessions.isEmpty) return 0;
  final weeks = data.sessions
      .map((s) {
        final d = s.startedAt;
        final monday = DateTime(d.year, d.month, d.day)
            .subtract(Duration(days: d.weekday - 1));
        return monday.millisecondsSinceEpoch;
      })
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  var count = 0;
  var cursor =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  for (final week in weeks) {
    final d = DateTime.fromMillisecondsSinceEpoch(week);
    if (cursor.difference(d).inDays.abs() <= 1 ||
        cursor.difference(d).inDays == 7) {
      count++;
      cursor = d;
    } else if (cursor.difference(d).inDays > 7) break;
  }
  return count;
}

String _compact(double value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(1)}m'
    : value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : '${value.round()}';

Future<void> _measurement(
    BuildContext context, WidgetRef ref, AppData data) async {
  final weight = TextEditingController();
  final waist = TextEditingController();
  await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
                            'Waist (${lengthUnit(data.useKg)}, optional)'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final enteredWeight = double.tryParse(weight.text);
                      if (enteredWeight == null || enteredWeight <= 0) return;
                      final enteredWaist = double.tryParse(waist.text);
                      ref.read(appControllerProvider.notifier).addMeasurement(
                          weightToKilograms(enteredWeight, data.useKg),
                          enteredWaist == null
                              ? null
                              : lengthToCentimeters(enteredWaist, data.useKg));
                      Navigator.pop(context);
                    },
                    child: const Text('Save'))
              ]));
}
