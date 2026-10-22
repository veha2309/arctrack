import 'package:flutter/material.dart';
import 'package:liquid_ui_components/liquid_ui_components.dart';
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
      data: (data) => _TodayBody(data: data),
    );
  }
}

class _SessionLauncher extends ConsumerStatefulWidget {
  const _SessionLauncher({required this.data});
  final AppData data;

  @override
  ConsumerState<_SessionLauncher> createState() => _SessionLauncherState();
}

class _SessionLauncherState extends ConsumerState<_SessionLauncher> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final template = data.todayTemplate;
    final active = data.activeSession;
    final action = active != null
        ? 'Resume workout'
        : template == null
            ? 'Open program'
            : template.isRest
                ? data.scheduleMode == ScheduleMode.rolling
                    ? 'Complete rest day'
                    : 'Open program'
                : 'Start workout';
    void start() {
      if (active != null) {
        context.go('/workout');
      } else if (template != null && !template.isRest) {
        ref.read(appControllerProvider.notifier).startTemplate(template);
        context.go('/workout');
      } else if (template?.isRest == true &&
          data.scheduleMode == ScheduleMode.rolling) {
        ref.read(appControllerProvider.notifier).skipToday();
      } else {
        context.go('/plan');
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: LiquidGlassMorph(
          key: const ValueKey('session-morph'),
          expanded: expanded,
          collapsedSize: Size(width.clamp(0, 228), 56),
          expandedSize: Size(width, 290),
          duration: const Duration(milliseconds: 280),
          settings: arcGlassSettings.copyWith(
              tintColor: ArcColors.blue, opacity: .18),
          expandedSettings: arcGlassSettings.copyWith(
              tintColor: const Color(0xFF446B6B), opacity: .3),
          sharedChild: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fitness_center, color: ArcColors.accent, size: 20),
            SizedBox(width: 10),
            Text('TODAY’S SESSION',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ]),
          expandedSharedPadding: const EdgeInsets.fromLTRB(22, 24, 64, 0),
          collapsedChild: TextButton(
            onPressed: () => setState(() => expanded = true),
            child: Semantics(
                label: 'Expand workout controls', child: SizedBox.expand()),
          ),
          expandedChild: Stack(children: [
            Positioned(
                right: 6,
                top: 8,
                child: IconButton(
                    tooltip: 'Minimize workout controls',
                    onPressed: () => setState(() => expanded = false),
                    icon: const Icon(Icons.unfold_less_rounded))),
            Positioned.fill(
              top: 64,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          active?.name ??
                              template?.name ??
                              'Choose your workout',
                          style: const TextStyle(
                              fontSize: 29, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(active != null
                          ? '${active.workingSets} completed sets so far'
                          : template == null
                              ? 'Build a routine or start from Train.'
                              : template.isRest
                                  ? 'Take the day to recharge.'
                                  : '${template.exercises.length} exercises · Your plan is ready'),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ArcGlassButton(
                            onPressed: start,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.arrow_forward_rounded),
                                  const SizedBox(width: 10),
                                  Flexible(child: Text(action)),
                                ])),
                      ),
                    ]),
              ),
            ),
          ]),
        ),
      );
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ARC / TRACK',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          LiquidGlassIconButton(
            settings: arcControlGlassSettings,
            onPressed: () => _settings(context, ref, data),
            icon: const Icon(Icons.tune),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Eyebrow(
            DateFormat('EEEE, d MMMM').format(DateTime.now()),
            color: ArcColors.blue,
          ),
          const SizedBox(height: 8),
          Text(
            data.activeSession != null
                ? 'Finish strong.'
                : template?.isRest == true
                    ? 'Recovery is training.'
                    : 'Ready to train?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          _SessionLauncher(data: data),
          const SizedBox(height: 24),
          const Eyebrow('Your momentum'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ArcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.sessions.where((s) => s.complete && DateTime.now().difference(s.startedAt).inDays < 7).length}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'WORKOUTS / 7 DAYS',
                        style: TextStyle(color: ArcColors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ArcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_weekSets(data)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'WORKING SETS',
                        style: TextStyle(color: ArcColors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Eyebrow('Coming up')),
              TextButton(
                onPressed: () => context.go('/plan'),
                child: const Text('Edit program'),
              ),
            ],
          ),
          ArcPanel(
            padding: EdgeInsets.zero,
            child: Column(children: _rotationRows(data).toList()),
          ),
          const SizedBox(height: 24),
          const Eyebrow('Recovery check-in'),
          const SizedBox(height: 10),
          ArcPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn == null
                            ? 'How are you feeling?'
                            : '${checkIn.score.round()} / 100',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        checkIn == null
                            ? 'A quick self-report before you train.'
                            : 'Your self-reported readiness today.',
                        style: const TextStyle(
                          color: ArcColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (checkIn == null)
                  TextButton(
                    onPressed: () => _checkIn(context, ref),
                    child: const Text('Check in'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Eyebrow('Recent workout')),
              TextButton(
                onPressed: () => context.go('/progress'),
                child: const Text('View insights'),
              ),
            ],
          ),
          if (last == null)
            const ArcPanel(
              child: Text('Your completed workouts will appear here.'),
            )
          else
            ArcPanel(
              child: Row(
                children: [
                  const Icon(Icons.history, color: ArcColors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          DateFormat('d MMM · H:mm').format(last.startedAt),
                          style: const TextStyle(
                            color: ArcColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${last.workingSets} sets',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
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
        yield Column(
          children: [
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 34,
                child: Text(
                  days[day],
                  style: TextStyle(
                    color: offset == 0 ? ArcColors.accent : ArcColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          ],
        );
      }
      return;
    }
    for (var i = 0; i < data.rotation.length.clamp(0, 4); i++) {
      final index = (data.rotationIndex + i) % data.rotation.length;
      final t =
          data.templates.where((e) => e.id == data.rotation[index]).firstOrNull;
      if (t != null)
        yield Column(
          children: [
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 24,
                child: Text(
                  i == 0 ? 'NOW' : '${i + 1}',
                  style: TextStyle(
                    color: i == 0 ? ArcColors.accent : ArcColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(t.name),
              trailing: Text(
                t.isRest ? 'REST' : '${t.exercises.length} EXERCISES',
                style: const TextStyle(color: ArcColors.muted, fontSize: 10),
              ),
            ),
            const Divider(height: 1, indent: 16),
          ],
        );
    }
  }
}

int _weekSets(AppData data) => data.sessions
    .where(
      (s) => s.complete && DateTime.now().difference(s.startedAt).inDays < 7,
    )
    .fold(0, (a, s) => a + s.workingSets);

Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
  var sleep = 3;
  var energy = 3;
  var ready = 3;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Daily check-in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _score('Sleep quality', sleep, (v) => setState(() => sleep = v)),
            _score('Energy', energy, (v) => setState(() => energy = v)),
            _score('Readiness', ready, (v) => setState(() => ready = v)),
            const SizedBox(height: 8),
            const Text(
              '1 = low, 5 = high',
              style: TextStyle(color: ArcColors.muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(appControllerProvider.notifier)
                  .addCheckIn(sleep, energy, ready, const {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Widget _score(String label, int value, ValueChanged<int> onChanged) => Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: value,
          items: [
            1,
            2,
            3,
            4,
            5,
          ].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ],
    );

Future<void> _settings(BuildContext context, WidgetRef ref, AppData data) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Settings')),
            ListTile(
              title: const Text('Weight units'),
              subtitle: Text(data.useKg ? 'Kilograms' : 'Pounds'),
              trailing: LiquidGlassSwitch(
                semanticLabel: 'Use kilograms',
                value: data.useKg,
                onChanged: (_) {
                  ref.read(appControllerProvider.notifier).toggleUnits();
                  Navigator.pop(sheetContext);
                },
              ),
            ),
            ListTile(
              title: const Text('Workout history & backup'),
              leading: const Icon(Icons.history),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/history');
              },
            ),
            ListTile(
              title: const Text('Reset rotation'),
              onTap: () {
                ref.read(appControllerProvider.notifier).resetRotation();
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
