import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_ui_components/liquid_ui_components.dart';
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
                const Eyebrow('Ready when you are', color: ArcColors.blue),
                const SizedBox(height: 8),
                Text(
                  'Choose your session.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start any routine. Your previous values will be ready in the log.',
                  style: TextStyle(color: ArcColors.muted),
                ),
                const SizedBox(height: 20),
                ...data.templates.where((e) => !e.isRest).map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ArcPanel(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              18,
                              12,
                              14,
                              12,
                            ),
                            title: Text(
                              t.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text('${t.exercises.length} exercises'),
                            trailing: const CircleAvatar(
                              backgroundColor: ArcColors.accent,
                              child: Icon(
                                Icons.arrow_forward,
                                color: ArcColors.background,
                              ),
                            ),
                            onTap: () => ref
                                .read(appControllerProvider.notifier)
                                .startTemplate(t),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        return _ActiveWorkout(data: data, session: session);
      },
    );
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
  final restLeft = ValueNotifier<int>(0);
  late final elapsedMinutes = ValueNotifier<int>(_elapsedMinutes);
  int get _elapsedMinutes => DateTime.now()
      .difference(widget.session.startedAt)
      .inMinutes
      .clamp(0, 9999);
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (restLeft.value > 0) restLeft.value--;
      elapsedMinutes.value = _elapsedMinutes;
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    restLeft.dispose();
    elapsedMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final completed = session.exercises.fold(
      0,
      (a, e) => a + e.sets.where((s) => s.completed).length,
    );
    final total = session.exercises.fold(0, (a, e) => a + e.sets.length);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name),
            Text(
              '$completed of $total sets complete',
              style: const TextStyle(
                color: ArcColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: restLeft,
            builder: (_, seconds, __) => seconds == 0
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => restLeft.value = 0,
                    child: Text('${seconds}s'),
                  ),
          ),
          LiquidGlassIconButton(
            settings: arcControlGlassSettings,
            onPressed: () => _pickExercise(),
            tooltip: 'Add exercise',
            icon: const Icon(Icons.playlist_add),
          ),
          PopupMenuButton(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
            onSelected: (_) => _discard(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: ArcColors.accent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$completed / $total sets logged',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: elapsedMinutes,
                      builder: (_, minutes, __) => Text(
                        '$minutes min',
                        style: const TextStyle(color: ArcColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : completed / total,
                    minHeight: 6,
                    backgroundColor: ArcColors.raised,
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: restLeft,
                  builder: (_, seconds, __) => seconds == 0
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: LiquidGlassToolbar(
                            settings: arcControlGlassSettings,
                            alignment: WrapAlignment.start,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: ArcColors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rest · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextButton(
                                onPressed: () => restLeft.value += 30,
                                child: const Text('+30s'),
                              ),
                              TextButton(
                                onPressed: () => restLeft.value = 0,
                                child: const Text('Skip'),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: session.exercises.length + 1,
              itemBuilder: (context, i) {
                if (i == session.exercises.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _pickExercise(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add exercise'),
                    ),
                  );
                }
                return _ExerciseBlock(
                  key: ValueKey(session.exercises[i].id),
                  data: widget.data,
                  log: session.exercises[i],
                  exerciseIndex: i,
                  onAddAfter: () => _pickExercise(afterIndex: i),
                  onRemove: () => _removeExercise(i),
                  onRest: (seconds) => restLeft.value = seconds,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: LiquidGlassSurface(
          settings: arcGlassSettings.copyWith(opacity: .7),
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VOLUME',
                      style: TextStyle(color: ArcColors.muted, fontSize: 10),
                    ),
                    Text(
                      '${formatWeight(widget.data.sessionVolume(session), widget.data.useKg)} ${weightUnit(widget.data.useKg)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const ValueKey('finish-workout'),
                  onPressed: completed == 0 ? null : _finish,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Finish workout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickExercise({int? afterIndex}) async {
    final existing = widget.session.exercises.map((e) => e.exerciseId).toSet();
    var query = '';
    final available = widget.data.exercises
        .where((exercise) => !existing.contains(exercise.id))
        .toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, change) {
          final filtered = available
              .where(
                (e) => '${e.name} ${e.muscle}'.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
          return SafeArea(
            child: SizedBox(
              height: (MediaQuery.sizeOf(sheetContext).height -
                      MediaQuery.viewInsetsOf(sheetContext).bottom) *
                  .7,
              child: Column(
                children: [
                  const ListTile(
                    title: Text('Add exercise'),
                    subtitle: Text(
                      'Previous values are filled when available.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search exercises or muscles',
                      ),
                      onChanged: (value) => change(() => query = value),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No exercises found'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (_, index) {
                              final exercise = filtered[index];
                              return ListTile(
                                title: Text(exercise.name),
                                subtitle: Text(exercise.muscle),
                                onTap: () =>
                                    Navigator.pop(sheetContext, exercise.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected == null) return;
    ref
        .read(appControllerProvider.notifier)
        .insertExerciseIntoWorkout(selected, afterIndex: afterIndex);
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
            content: Text(
              hasWork
                  ? 'Its completed sets will be removed from this workout.'
                  : 'This only changes the current workout.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: ArcColors.danger),
                ),
              ),
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
              'The active session and its logged sets will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: ArcColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (yes) ref.read(appControllerProvider.notifier).discardWorkout();
  }

  Future<void> _finish() async {
    final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Finish workout?'),
            content: Text(
              '${widget.session.workingSets} working sets · ${formatWeight(widget.data.sessionVolume(widget.session), widget.data.useKg)} ${weightUnit(widget.data.useKg)} volume',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              ArcGlassButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Finish'),
              ),
            ],
          ),
        ) ??
        false;
    if (yes && mounted) {
      ref.read(appControllerProvider.notifier).finishWorkout();
      if (mounted) showArcToast(context, 'Workout saved');
    }
  }
}

class _ExerciseBlock extends ConsumerWidget {
  const _ExerciseBlock({
    super.key,
    required this.data,
    required this.log,
    required this.exerciseIndex,
    required this.onAddAfter,
    required this.onRemove,
    required this.onRest,
  });
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
    final count = log.sets.where((s) => s.completed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: ArcPanel(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise?.name ?? 'Exercise',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${exercise?.muscle ?? ''} · $count/${log.sets.length} sets · ${log.restSeconds}s rest',
                          style: const TextStyle(
                            color: ArcColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Exercise actions',
                    onSelected: (action) =>
                        action == 'add' ? onAddAfter() : onRemove(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add',
                        child: Text('Add exercise after'),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove exercise'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 34, child: Text('SET', style: _head)),
                  const Expanded(child: Text('PREVIOUS', style: _head)),
                  SizedBox(
                    width: 76,
                    child: Text(
                      exercise?.kind == ExerciseKind.timed
                          ? 'SECONDS'
                          : exercise?.kind == ExerciseKind.distance
                              ? (data.useKg ? 'KM' : 'MI')
                              : exercise?.kind == ExerciseKind.assisted
                                  ? 'ASSIST'
                                  : weightUnit(data.useKg).toUpperCase(),
                      style: _head,
                    ),
                  ),
                  SizedBox(
                    width: 66,
                    child: Text(
                      exercise?.kind == ExerciseKind.timed ||
                              exercise?.kind == ExerciseKind.distance
                          ? ''
                          : 'REPS',
                      style: _head,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            if (exercise?.kind == ExerciseKind.assisted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  data.activeSession?.bodyWeightKg == null &&
                          data.bodyWeightAt(data.activeSession!.startedAt) ==
                              null
                      ? 'Enter assistance in ${weightUnit(data.useKg)}. Log body weight in Insights to calculate effective load.'
                      : 'Enter assistance in ${weightUnit(data.useKg)}. Effective load = body weight minus assistance.',
                  style: const TextStyle(color: ArcColors.blue, fontSize: 12),
                ),
              ),
            if (exercise?.kind == ExerciseKind.assisted)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: () => _bodyWeight(context, ref),
                  icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                  label: Text(
                    data.activeSession?.bodyWeightKg == null
                        ? 'Set body weight for this workout'
                        : 'Body weight: ${formatWeight(data.activeSession!.bodyWeightKg!, data.useKg)} ${weightUnit(data.useKg)}',
                  ),
                ),
              ),
            ...log.sets.asMap().entries.map(
                  (entry) => _SetRow(
                    key: ValueKey(entry.value.id),
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
                    onRest: onRest,
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: TextButton.icon(
                onPressed: () => ref
                    .read(appControllerProvider.notifier)
                    .addSet(exerciseIndex),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bodyWeight(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _WorkoutBodyWeightDialog(
        useKg: data.useKg,
        kilograms: data.activeSession?.bodyWeightKg,
      ),
    );
    if (value != null)
      ref.read(appControllerProvider.notifier).setWorkoutBodyWeight(value);
  }

  static const _head = TextStyle(
    color: ArcColors.muted,
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
}

class _SetRow extends ConsumerWidget {
  const _SetRow({
    super.key,
    required this.log,
    required this.kind,
    required this.set,
    required this.previous,
    required this.exerciseIndex,
    required this.setIndex,
    required this.useKg,
    required this.restSeconds,
    required this.onRest,
  });
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
          child: const Icon(Icons.delete),
        ),
        onDismissed: (_) {
          final controller = ref.read(appControllerProvider.notifier);
          final sessionId =
              ref.read(appControllerProvider).requireValue.activeSession!.id;
          controller.removeSet(exerciseIndex, setIndex);
          showArcToast(context, 'Set ${setIndex + 1} removed',
              icon: Icons.delete_outline_rounded,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () =>
                    controller.restoreSet(sessionId, log.id, setIndex, set),
              ));
        },
        child: InkWell(
          onLongPress: () => _advanced(context, ref),
          child: Container(
            color:
                set.completed ? ArcColors.accent.withValues(alpha: .06) : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: IconButton(
                    tooltip: 'Set ${setIndex + 1} details',
                    padding: EdgeInsets.zero,
                    onPressed: () => _advanced(context, ref),
                    icon: Text(
                      set.kind == SetKind.warmup ? 'W' : '${setIndex + 1}',
                      style: const TextStyle(
                        color: ArcColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: 'Use previous set values',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: previous == null
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _update(
                                ref,
                                set.copyWith(
                                  weightKg: previous!.weightKg,
                                  reps: previous!.reps,
                                  seconds: previous!.seconds,
                                  distanceM: previous!.distanceM,
                                  completed: false,
                                ),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                            color: ArcColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: _LogInput(
                    key: ValueKey('${set.id}-${kind.name}-primary'),
                    value: kind == ExerciseKind.timed
                        ? (set.seconds == 0 ? '' : '${set.seconds}')
                        : kind == ExerciseKind.distance
                            ? (set.distanceM == 0
                                ? ''
                                : distanceForDisplay(
                                    set.distanceM,
                                    useKg,
                                  ).toStringAsFixed(2))
                            : (set.weightKg == 0
                                ? (kind == ExerciseKind.assisted ? '0' : '')
                                : formatWeight(set.weightKg, useKg)),
                    textInputAction: kind == ExerciseKind.timed ||
                            kind == ExerciseKind.distance
                        ? TextInputAction.done
                        : TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      kind == ExerciseKind.timed
                          ? FilteringTextInputFormatter.digitsOnly
                          : TextInputFormatter.withFunction(
                              (old, next) =>
                                  RegExp(r'^\d*\.?\d*$').hasMatch(next.text)
                                      ? next
                                      : old,
                            ),
                    ],
                    onChanged: (v) => _update(
                      ref,
                      kind == ExerciseKind.timed
                          ? set.copyWith(seconds: int.tryParse(v) ?? 0)
                          : kind == ExerciseKind.distance
                              ? set.copyWith(
                                  distanceM: distanceToMeters(
                                    double.tryParse(v) ?? 0,
                                    useKg,
                                  ),
                                )
                              : set.copyWith(
                                  weightKg: weightToKilograms(
                                    double.tryParse(v) ?? 0,
                                    useKg,
                                  ),
                                ),
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (kind != ExerciseKind.timed && kind != ExerciseKind.distance)
                  SizedBox(
                    width: 60,
                    child: _LogInput(
                      key: ValueKey('${set.id}-reps'),
                      textInputAction: TextInputAction.done,
                      value: set.reps == 0 ? '' : '${set.reps}',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _update(
                          ref, set.copyWith(reps: int.tryParse(v) ?? 0)),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                if (kind == ExerciseKind.timed || kind == ExerciseKind.distance)
                  const SizedBox(width: 66),
                SizedBox(
                  width: 42,
                  child: IconButton(
                    tooltip: set.completed ? 'Mark set incomplete' : 'Log set',
                    onPressed: () {
                      final current = ref
                          .read(appControllerProvider)
                          .requireValue
                          .activeSession!
                          .exercises[exerciseIndex]
                          .sets[setIndex];
                      final valid = switch (kind) {
                        ExerciseKind.strength =>
                          current.weightKg > 0 && current.reps > 0,
                        ExerciseKind.assisted ||
                        ExerciseKind.bodyweight =>
                          current.reps > 0,
                        ExerciseKind.timed => current.seconds > 0,
                        ExerciseKind.distance => current.distanceM > 0,
                      };
                      if (!current.completed && !valid) {
                        showArcToast(
                            context,
                            switch (kind) {
                              ExerciseKind.strength =>
                                'Enter weight and reps before logging this set.',
                              ExerciseKind.assisted ||
                              ExerciseKind.bodyweight =>
                                'Enter reps before logging this set.',
                              ExerciseKind.timed =>
                                'Enter seconds before logging this set.',
                              ExerciseKind.distance =>
                                'Enter distance before logging this set.',
                            },
                            icon: Icons.info_outline_rounded);
                        return;
                      }
                      FocusScope.of(context).unfocus();
                      HapticFeedback.lightImpact();
                      _update(
                          ref, current.copyWith(completed: !current.completed));
                      if (!current.completed) onRest(restSeconds);
                    },
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      set.completed
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: set.completed ? ArcColors.accent : ArcColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  void _update(WidgetRef ref, LoggedSet next) {
    final valid = switch (kind) {
      ExerciseKind.strength => next.weightKg > 0 && next.reps > 0,
      ExerciseKind.assisted || ExerciseKind.bodyweight => next.reps > 0,
      ExerciseKind.timed => next.seconds > 0,
      ExerciseKind.distance => next.distanceM > 0,
    };
    ref.read(appControllerProvider.notifier).updateSet(
          exerciseIndex,
          setIndex,
          valid ? next : next.copyWith(completed: false),
        );
  }

  Future<void> _advanced(BuildContext context, WidgetRef ref) async {
    final next = await showModalBottomSheet<LoggedSet>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SetDetailsSheet(set: set),
    );
    if (next != null) _update(ref, next);
  }
}

/// Keeps autofill and undo reflected in inputs without moving the typing cursor.
class _LogInput extends StatefulWidget {
  const _LogInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.keyboardType,
    required this.inputFormatters,
    required this.textInputAction,
    required this.decoration,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final TextInputAction textInputAction;
  final InputDecoration decoration;
  @override
  State<_LogInput> createState() => _LogInputState();
}

class _LogInputState extends State<_LogInput> {
  late final controller = TextEditingController(text: widget.value);
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant _LogInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!focus.hasFocus &&
        widget.value != oldWidget.value &&
        controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focus,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        decoration: widget.decoration,
      );
}

class _WorkoutBodyWeightDialog extends StatefulWidget {
  const _WorkoutBodyWeightDialog({required this.useKg, this.kilograms});
  final bool useKg;
  final double? kilograms;
  @override
  State<_WorkoutBodyWeightDialog> createState() =>
      _WorkoutBodyWeightDialogState();
}

class _WorkoutBodyWeightDialogState extends State<_WorkoutBodyWeightDialog> {
  late final weight = TextEditingController(
    text: widget.kilograms == null
        ? ''
        : formatWeight(widget.kilograms!, widget.useKg),
  );
  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Workout body weight'),
        content: TextField(
          controller: weight,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Body weight (${weightUnit(widget.useKg)})',
            helperText: 'Saved with this workout.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ArcGlassButton(
            onPressed: () {
              final value = double.tryParse(weight.text);
              if (value == null || !value.isFinite || value <= 0) return;
              Navigator.pop(context, weightToKilograms(value, widget.useKg));
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _SetDetailsSheet extends StatefulWidget {
  const _SetDetailsSheet({required this.set});
  final LoggedSet set;
  @override
  State<_SetDetailsSheet> createState() => _SetDetailsSheetState();
}

class _SetDetailsSheetState extends State<_SetDetailsSheet> {
  late SetKind kind = widget.set.kind;
  late final rpe = TextEditingController(
    text: widget.set.rpe?.toString() ?? '',
  );
  late final rir = TextEditingController(
    text: widget.set.rir?.toString() ?? '',
  );
  late final notes = TextEditingController(text: widget.set.notes ?? '');
  @override
  void dispose() {
    rpe.dispose();
    rir.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Set details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Set type'),
                items: SetKind.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (v) => setState(() => kind = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rpe,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'RPE (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rir,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'RIR (optional)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: rpe,
                builder: (context, value, _) {
                  final effort = double.tryParse(value.text);
                  final sliderValue = effort != null && effort.isFinite
                      ? effort.clamp(0.0, 10.0)
                      : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sliderValue == 0
                            ? 'RPE: not set'
                            : 'RPE: ${sliderValue.toStringAsFixed(1)} / 10',
                      ),
                      LiquidGlassSlider(
                        settings: arcControlGlassSettings,
                        value: sliderValue,
                        max: 10,
                        divisions: 20,
                        height: 56,
                        semanticLabel: 'Rate of perceived exertion',
                        label: sliderValue == 0
                            ? 'Not set'
                            : sliderValue.toStringAsFixed(1),
                        thumbIcon: Icons.bolt,
                        onChanged: (value) => rpe.text =
                            value == 0 ? '' : value.toStringAsFixed(1),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ArcGlassButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      widget.set.copyWith(
                        kind: kind,
                        rpe: double.tryParse(rpe.text),
                        rir: int.tryParse(rir.text),
                        notes: notes.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save details'),
                ),
              ),
            ],
          ),
        ),
      );
}
