import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);
    return async.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (data) {
          final session = data.activeSession;
          if (session == null)
            return Scaffold(
                appBar: AppBar(title: const Text('Train')),
                body: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      const Eyebrow('Ready when you are',
                          color: ArcColors.blue),
                      const SizedBox(height: 8),
                      Text('Choose your session.',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text(
                          'Start any routine. Your previous values will be ready in the log.',
                          style: TextStyle(color: ArcColors.muted)),
                      const SizedBox(height: 20),
                      ...data.templates
                          .where((e) => !e.isRest)
                          .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ArcPanel(
                                  padding: EdgeInsets.zero,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.fromLTRB(
                                        18, 12, 14, 12),
                                    title: Text(t.name,
                                        style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800)),
                                    subtitle:
                                        Text('${t.exercises.length} exercises'),
                                    trailing: const CircleAvatar(
                                        backgroundColor: ArcColors.accent,
                                        child: Icon(Icons.arrow_forward,
                                            color: ArcColors.background)),
                                    onTap: () => ref
                                        .read(appControllerProvider.notifier)
                                        .startTemplate(t),
                                  )))),
                    ]));
          return _ActiveWorkout(data: data, session: session);
        });
  }
}

class _ActiveWorkout extends ConsumerStatefulWidget {
  const _ActiveWorkout({required this.data, required this.session});
  final AppData data;
  final WorkoutSession session;
  @override
  ConsumerState<_ActiveWorkout> createState() => _ActiveWorkoutState();
}

class _ActiveWorkoutState extends ConsumerState<_ActiveWorkout> {
  Timer? ticker;
  int restLeft = 0;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && restLeft > 0) setState(() => restLeft--);
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final completed = session.exercises
        .fold(0, (a, e) => a + e.sets.where((s) => s.completed).length);
    final total = session.exercises.fold(0, (a, e) => a + e.sets.length);
    return Scaffold(
      appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.name),
            Text('$completed of $total sets complete',
                style: const TextStyle(
                    color: ArcColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.normal))
          ]),
          actions: [
            if (restLeft > 0)
              TextButton(
                  onPressed: () => setState(() => restLeft = 0),
                  child: Text('${restLeft}s')),
            IconButton(
                onPressed: () => _pickExercise(),
                tooltip: 'Add exercise',
                icon: const Icon(Icons.playlist_add)),
            PopupMenuButton(
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'discard', child: Text('Discard workout'))
                    ],
                onSelected: (_) => _discard())
          ]),
      body: ListView.builder(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: session.exercises.length + 1,
          itemBuilder: (context, i) {
            if (i == session.exercises.length) {
              return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: OutlinedButton.icon(
                      onPressed: () => _pickExercise(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add exercise')));
            }
            return _ExerciseBlock(
                data: widget.data,
                log: session.exercises[i],
                exerciseIndex: i,
                onAddAfter: () => _pickExercise(afterIndex: i),
                onRemove: () => _removeExercise(i),
                onRest: (seconds) => setState(() => restLeft = seconds));
          }),
      bottomSheet: Container(
          color: ArcColors.surface,
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.paddingOf(context).bottom + 10),
          child: Row(children: [
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('VOLUME',
                      style: TextStyle(color: ArcColors.muted, fontSize: 10)),
                  Text(
                      '${formatWeight(session.volume, widget.data.useKg)} ${weightUnit(widget.data.useKg)}',
                      style: const TextStyle(fontWeight: FontWeight.w700))
                ])),
            Expanded(
                flex: 2,
                child: FilledButton(
                    onPressed: completed == 0 ? null : _finish,
                    child: const Text('Finish workout')))
          ])),
    );
  }

  Future<void> _pickExercise({int? afterIndex}) async {
    final existing = widget.session.exercises.map((e) => e.exerciseId).toSet();
    final available = widget.data.exercises
        .where((exercise) => !existing.contains(exercise.id))
        .toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .7,
          child: Column(children: [
            const ListTile(
                title: Text('Add exercise'),
                subtitle: Text('Previous values are filled when available.')),
            const Divider(height: 1),
            Expanded(
              child: available.isEmpty
                  ? const Center(
                      child: Text('Every exercise is already in this workout'))
                  : ListView.separated(
                      itemCount: available.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, index) {
                        final exercise = available[index];
                        return ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(exercise.muscle),
                          onTap: () => Navigator.pop(sheetContext, exercise.id),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
    if (selected == null) return;
    ref.read(appControllerProvider.notifier).insertExerciseIntoWorkout(
          selected,
          afterIndex: afterIndex,
        );
  }

  Future<void> _removeExercise(int index) async {
    final log = widget.session.exercises[index];
    final exercise = widget.data.exercises
        .where((item) => item.id == log.exerciseId)
        .firstOrNull;
    final hasWork = log.sets.any((set) => set.completed);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Remove ${exercise?.name ?? 'exercise'}?'),
            content: Text(hasWork
                ? 'Its completed sets will be removed from this workout.'
                : 'This only changes the current workout.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Remove',
                      style: TextStyle(color: ArcColors.danger))),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      ref.read(appControllerProvider.notifier).removeExerciseFromWorkout(index);
    }
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                    title: const Text('Discard workout?'),
                    content: const Text(
                        'The active session and its logged sets will be removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Keep')),
                      TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Discard',
                              style: TextStyle(color: ArcColors.danger)))
                    ])) ??
        false;
    if (yes) ref.read(appControllerProvider.notifier).discardWorkout();
  }

  Future<void> _finish() async {
    final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                    title: const Text('Finish workout?'),
                    content: Text(
                        '${widget.session.workingSets} working sets · ${formatWeight(widget.session.volume, widget.data.useKg)} ${weightUnit(widget.data.useKg)} volume'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Finish'))
                    ])) ??
        false;
    if (yes) {
      ref.read(appControllerProvider.notifier).finishWorkout();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Workout saved')));
    }
  }
}

class _ExerciseBlock extends ConsumerWidget {
  const _ExerciseBlock(
      {required this.data,
      required this.log,
      required this.exerciseIndex,
      required this.onAddAfter,
      required this.onRemove,
      required this.onRest});
  final AppData data;
  final ExerciseLog log;
  final int exerciseIndex;
  final VoidCallback onAddAfter;
  final VoidCallback onRemove;
  final ValueChanged<int> onRest;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise =
        data.exercises.where((e) => e.id == log.exerciseId).firstOrNull;
    final priorSessions = data.sessions.where((s) => s.complete).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final priorLog = priorSessions
        .expand((s) => s.exercises)
        .where((l) => l.exerciseId == log.exerciseId)
        .firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(exercise?.name ?? 'Exercise',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(exercise?.muscle ?? '',
                      style:
                          const TextStyle(color: ArcColors.muted, fontSize: 12))
                ])),
            PopupMenuButton<String>(
                tooltip: 'Exercise actions',
                onSelected: (action) =>
                    action == 'add' ? onAddAfter() : onRemove(),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'add', child: Text('Add exercise after')),
                      PopupMenuItem(
                          value: 'remove', child: Text('Remove exercise')),
                    ])
          ])),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const SizedBox(width: 34, child: Text('SET', style: _head)),
            const Expanded(child: Text('PREVIOUS', style: _head)),
            SizedBox(
                width: 76,
                child: Text(
                    exercise?.kind == ExerciseKind.timed
                        ? 'SECONDS'
                        : exercise?.kind == ExerciseKind.distance
                            ? (data.useKg ? 'KM' : 'MI')
                            : weightUnit(data.useKg).toUpperCase(),
                    style: _head)),
            SizedBox(
                width: 66,
                child: Text(
                    exercise?.kind == ExerciseKind.timed ||
                            exercise?.kind == ExerciseKind.distance
                        ? ''
                        : 'REPS',
                    style: _head)),
            const SizedBox(width: 42)
          ])),
      ...log.sets.asMap().entries.map((entry) => _SetRow(
          log: log,
          kind: exercise?.kind ?? ExerciseKind.strength,
          set: entry.value,
          previous: priorLog != null &&
                  entry.key < priorLog.sets.length &&
                  priorLog.sets[entry.key].completed
              ? priorLog.sets[entry.key]
              : null,
          exerciseIndex: exerciseIndex,
          setIndex: entry.key,
          useKg: data.useKg,
          restSeconds: log.restSeconds,
          onRest: onRest)),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: TextButton.icon(
              onPressed: () => ref
                  .read(appControllerProvider.notifier)
                  .addSet(exerciseIndex),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add set'))),
      const Divider(height: 1),
    ]);
  }

  static const _head = TextStyle(
      color: ArcColors.muted, fontSize: 10, fontWeight: FontWeight.w700);
}

class _SetRow extends ConsumerWidget {
  const _SetRow(
      {required this.log,
      required this.kind,
      required this.set,
      required this.previous,
      required this.exerciseIndex,
      required this.setIndex,
      required this.useKg,
      required this.restSeconds,
      required this.onRest});
  final ExerciseLog log;
  final ExerciseKind kind;
  final LoggedSet set;
  final LoggedSet? previous;
  final int exerciseIndex;
  final int setIndex;
  final bool useKg;
  final int restSeconds;
  final ValueChanged<int> onRest;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
      key: ValueKey(set.id),
      direction: DismissDirection.endToStart,
      background: Container(
          color: ArcColors.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: const Icon(Icons.delete)),
      onDismissed: (_) => ref
          .read(appControllerProvider.notifier)
          .removeSet(exerciseIndex, setIndex),
      child: InkWell(
          onLongPress: () => _advanced(context, ref),
          child: Container(
              color: set.completed
                  ? ArcColors.accent.withValues(alpha: .06)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Row(children: [
                SizedBox(
                    width: 34,
                    child: Text('${setIndex + 1}',
                        style: TextStyle(
                            color: set.kind == SetKind.warmup
                                ? ArcColors.muted
                                : ArcColors.text))),
                Expanded(
                    child: Text(
                        previous == null
                            ? '—'
                            : kind == ExerciseKind.timed
                                ? (previous!.seconds == 0
                                    ? '—'
                                    : '${previous!.seconds}s')
                                : kind == ExerciseKind.distance
                                    ? (previous!.distanceM == 0
                                        ? '—'
                                        : '${distanceForDisplay(previous!.distanceM, useKg).toStringAsFixed(2)} ${distanceUnit(useKg)}')
                                    : previous!.weightKg == 0
                                        ? (previous!.reps == 0
                                            ? '—'
                                            : '${previous!.reps} reps')
                                        : '${formatWeight(previous!.weightKg, useKg)} × ${previous!.reps}',
                        style: const TextStyle(
                            color: ArcColors.muted, fontSize: 12))),
                SizedBox(
                    width: 70,
                    child: TextFormField(
                        key: ValueKey('${set.id}-${kind.name}-primary'),
                        initialValue: kind == ExerciseKind.timed
                            ? (set.seconds == 0 ? '' : '${set.seconds}')
                            : kind == ExerciseKind.distance
                                ? (set.distanceM == 0
                                    ? ''
                                    : distanceForDisplay(set.distanceM, useKg)
                                        .toStringAsFixed(2))
                                : (set.weightKg == 0
                                    ? ''
                                    : formatWeight(set.weightKg, useKg)),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        onChanged: (v) => _update(
                            ref,
                            kind == ExerciseKind.timed
                                ? set.copyWith(seconds: int.tryParse(v) ?? 0)
                                : kind == ExerciseKind.distance
                                    ? set.copyWith(
                                        distanceM: distanceToMeters(
                                            double.tryParse(v) ?? 0, useKg))
                                    : set.copyWith(
                                        weightKg: weightToKilograms(
                                            double.tryParse(v) ?? 0, useKg))),
                        decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 9)))),
                const SizedBox(width: 6),
                if (kind != ExerciseKind.timed && kind != ExerciseKind.distance)
                  SizedBox(
                      width: 60,
                      child: TextFormField(
                          initialValue: set.reps == 0 ? '' : '${set.reps}',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (v) => _update(
                              ref, set.copyWith(reps: int.tryParse(v) ?? 0)),
                          decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 9)))),
                if (kind == ExerciseKind.timed || kind == ExerciseKind.distance)
                  const SizedBox(width: 66),
                SizedBox(
                    width: 42,
                    child: IconButton(
                        onPressed: () {
                          _update(ref, set.copyWith(completed: !set.completed));
                          if (!set.completed) onRest(restSeconds);
                        },
                        padding: EdgeInsets.zero,
                        icon: Icon(
                            set.completed
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: set.completed
                                ? ArcColors.accent
                                : ArcColors.muted))),
              ]))));
  void _update(WidgetRef ref, LoggedSet next) => ref
      .read(appControllerProvider.notifier)
      .updateSet(exerciseIndex, setIndex, next);
  Future<void> _advanced(BuildContext context, WidgetRef ref) async {
    var kind = set.kind;
    final rpe = TextEditingController(text: set.rpe?.toString() ?? '');
    final rir = TextEditingController(text: set.rir?.toString() ?? '');
    final notes = TextEditingController(text: set.notes ?? '');
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, change) => Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Set details',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Set type'),
                      items: SetKind.values
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)))
                          .toList(),
                      onChanged: (v) => change(() => kind = v!)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: rpe,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'RPE (optional)'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: rir,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'RIR (optional)')))
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                      controller: notes,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)')),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () {
                            _update(
                                ref,
                                set.copyWith(
                                    kind: kind,
                                    rpe: double.tryParse(rpe.text),
                                    rir: int.tryParse(rir.text),
                                    notes: notes.text.trim()));
                            Navigator.pop(context);
                          },
                          child: const Text('Save details')))
                ]))));
  }
}
