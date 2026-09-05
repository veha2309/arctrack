import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);
    return async.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Could not load data\n$e'))),
        data: (data) => _TodayBody(data: data));
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.data});
  final AppData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = data.todayTemplate;
    final last = data.sessions.firstOrNull;
    final checkIn = data.checkIns
        .where((e) => DateUtils.isSameDay(e.date, DateTime.now()))
        .firstOrNull;
    final readiness = checkIn?.score ?? _trainingReadiness(data);
    return Scaffold(
      appBar: AppBar(
          title: const Text('ARCTRACK',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          actions: [
            TextButton(
                onPressed: () => _settings(context, ref, data),
                child: Text(data.useKg ? 'KG' : 'LB'))
          ]),
      body: ListView(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: const TextStyle(color: ArcColors.muted))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(template?.name ?? 'No session planned',
                style: Theme.of(context).textTheme.headlineMedium)),
        if (data.activeSession != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: FilledButton.icon(
                  onPressed: () => context.go('/workout'),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Resume ${data.activeSession!.name}')))
        else if (template != null && !template.isRest)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: FilledButton(
                  onPressed: () {
                    ref
                        .read(appControllerProvider.notifier)
                        .startTemplate(template);
                    context.go('/workout');
                  },
                  child: const Text('Start workout')))
        else if (template?.isRest == true)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: OutlinedButton(
                  onPressed: data.scheduleMode == ScheduleMode.rolling
                      ? () =>
                          ref.read(appControllerProvider.notifier).skipToday()
                      : null,
                  child: Text(data.scheduleMode == ScheduleMode.rolling
                      ? 'Complete rest day'
                      : 'Rest scheduled'))),
        const SectionHeader('Readiness'),
        Container(
            decoration: const BoxDecoration(
                border: Border.symmetric(
                    horizontal: BorderSide(color: ArcColors.line))),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Metric(
                  label: 'TODAY',
                  value: '${readiness.round()}%',
                  detail:
                      checkIn == null ? 'Training estimate' : 'From check-in'),
              Metric(
                  label: 'LAST SESSION',
                  value: last == null ? '—' : '${last.workingSets} sets',
                  detail: last?.name),
              Metric(
                  label: '7 DAY LOAD',
                  value: '${_weekSets(data)}',
                  detail: 'working sets')
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(_guidance(readiness),
                style: const TextStyle(color: ArcColors.muted, height: 1.4))),
        if (checkIn == null)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton(
                  onPressed: () => _checkIn(context, ref),
                  child: const Text('Daily check-in'))),
        const SectionHeader('Up next'),
        ..._rotationRows(data),
        const SectionHeader('Previous'),
        if (last == null)
          const EmptyState(
              title: 'No completed workouts',
              body: 'Your previous session will appear here.')
        else
          ListTile(
              title: Text(last.name),
              subtitle: Text(DateFormat('d MMM · H:mm').format(last.startedAt)),
              trailing: Text(
                  '${formatWeight(last.volume, data.useKg)} ${weightUnit(data.useKg)}',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Iterable<Widget> _rotationRows(AppData data) sync* {
    if (data.scheduleMode == ScheduleMode.weekly) {
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      final today = DateTime.now().weekday - 1;
      for (var offset = 0; offset < 4; offset++) {
        final day = (today + offset) % 7;
        final id =
            data.weeklySchedule.length > day ? data.weeklySchedule[day] : null;
        final t = data.templates.where((e) => e.id == id).firstOrNull;
        yield Column(children: [
          ListTile(
            dense: true,
            leading: SizedBox(
              width: 34,
              child: Text(days[day],
                  style: TextStyle(
                      color: offset == 0 ? ArcColors.accent : ArcColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            title: Text(t?.name ?? 'Unscheduled'),
            trailing: Text(
              t == null
                  ? '—'
                  : t.isRest
                      ? 'REST'
                      : '${t.exercises.length} EXERCISES',
              style: const TextStyle(color: ArcColors.muted, fontSize: 10),
            ),
          ),
          const Divider(height: 1, indent: 16),
        ]);
      }
      return;
    }
    for (var i = 0; i < data.rotation.length.clamp(0, 4); i++) {
      final index = (data.rotationIndex + i) % data.rotation.length;
      final t =
          data.templates.where((e) => e.id == data.rotation[index]).firstOrNull;
      if (t != null)
        yield Column(children: [
          ListTile(
              dense: true,
              leading: SizedBox(
                  width: 24,
                  child: Text(i == 0 ? 'NOW' : '${i + 1}',
                      style: TextStyle(
                          color: i == 0 ? ArcColors.accent : ArcColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700))),
              title: Text(t.name),
              trailing: Text(
                  t.isRest ? 'REST' : '${t.exercises.length} EXERCISES',
                  style:
                      const TextStyle(color: ArcColors.muted, fontSize: 10))),
          const Divider(height: 1, indent: 16)
        ]);
    }
  }
}

double _trainingReadiness(AppData data) {
  final now = DateTime.now();
  final sets48h = data.sessions
      .where((s) => now.difference(s.startedAt).inHours < 48)
      .fold<int>(0, (a, s) => a + s.workingSets);
  return (92 - sets48h * 1.6).clamp(35, 92);
}

int _weekSets(AppData data) => data.sessions
    .where((s) => DateTime.now().difference(s.startedAt).inDays < 7)
    .fold(0, (a, s) => a + s.workingSets);
String _guidance(double score) => score >= 75
    ? 'Recovery looks sufficient for the planned session. This estimate uses recent training unless you complete a check-in.'
    : score >= 55
        ? 'Moderate readiness. Keep the planned session, but adjust load if warm-ups feel unusually difficult.'
        : 'Recent load is high. Consider reducing working sets or taking a rest day.';

Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
  var sleep = 3;
  var energy = 3;
  var ready = 3;
  await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                  title: const Text('Daily check-in'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    _score('Sleep quality', sleep,
                        (v) => setState(() => sleep = v)),
                    _score('Energy', energy, (v) => setState(() => energy = v)),
                    _score(
                        'Readiness', ready, (v) => setState(() => ready = v)),
                    const SizedBox(height: 8),
                    const Text('1 = low, 5 = high',
                        style: TextStyle(color: ArcColors.muted, fontSize: 12)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          ref
                              .read(appControllerProvider.notifier)
                              .addCheckIn(sleep, energy, ready, const {});
                          Navigator.pop(context);
                        },
                        child: const Text('Save'))
                  ])));
}

Widget _score(String label, int value, ValueChanged<int> onChanged) =>
    Row(children: [
      Expanded(child: Text(label)),
      DropdownButton<int>(
          value: value,
          items: [1, 2, 3, 4, 5]
              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
              .toList(),
          onChanged: (v) => onChanged(v!))
    ]);

Future<void> _settings(BuildContext context, WidgetRef ref, AppData data) =>
    showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(title: Text('Settings')),
              ListTile(
                  title: const Text('Weight units'),
                  subtitle: Text(data.useKg ? 'Kilograms' : 'Pounds'),
                  trailing: Switch(
                      value: data.useKg,
                      onChanged: (_) => ref
                          .read(appControllerProvider.notifier)
                          .toggleUnits())),
              ListTile(
                  title: const Text('Reset rotation'),
                  onTap: () {
                    ref.read(appControllerProvider.notifier).resetRotation();
                    Navigator.pop(context);
                  }),
              const SizedBox(height: 12)
            ])));
