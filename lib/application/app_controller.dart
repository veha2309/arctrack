import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/app_database.dart';
import '../data/app_repository.dart';
import '../data/auto_backup_service.dart';
import '../domain/models.dart';

final databaseProvider = Provider((ref) {
  final db = ArcDatabase();
  ref.onDispose(db.close);
  return db;
});
final repositoryProvider = Provider<AppRepository>(
    (ref) => LocalAppRepository(ref.watch(databaseProvider)));
final appControllerProvider =
    AsyncNotifierProvider<AppController, AppData>(AppController.new);

class AppController extends AsyncNotifier<AppData> {
  static const _uuid = Uuid();
  Timer? _saveTimer;
  AppRepository get _repository => ref.read(repositoryProvider);
  final _autoBackup = AutoBackupService();

  @override
  Future<AppData> build() async {
    ref.onDispose(() => _saveTimer?.cancel());
    return await _repository.load() ?? seedData();
  }

  void _set(AppData next) {
    state = AsyncData(next);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 180), () async {
      await _repository.save(next);
      try {
        await _autoBackup.write(next.encode());
      } catch (_) {
        // Local saving remains authoritative if the selected cloud provider is
        // temporarily offline. Its next data update will retry the same file.
      }
    });
  }

  void startTemplate(WorkoutTemplate template) {
    final data = state.requireValue;
    if (data.activeSession != null) return;
    final logs = template.exercises.map((item) {
      final previous = _previousLog(item.exerciseId);
      final sets = List.generate(item.sets, (i) {
        final old = previous != null &&
                i < previous.sets.length &&
                previous.sets[i].completed
            ? previous.sets[i]
            : null;
        return LoggedSet(
            id: _uuid.v4(),
            weightKg: old?.weightKg ?? 0,
            reps: old?.reps ?? item.reps,
            seconds: old?.seconds ?? 0,
            distanceM: old?.distanceM ?? 0);
      });
      return ExerciseLog(
          id: _uuid.v4(),
          exerciseId: item.exerciseId,
          sets: sets,
          restSeconds: item.restSeconds);
    }).toList();
    _set(data.copyWith(
        activeSession: WorkoutSession(
            id: _uuid.v4(),
            name: template.name,
            startedAt: DateTime.now(),
            templateId: template.id,
            exercises: logs)));
  }

  ExerciseLog? _previousLog(String exerciseId) {
    final sessions = state.requireValue.sessions
        .where((s) => s.complete)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    for (final session in sessions) {
      for (final log in session.exercises) {
        if (log.exerciseId == exerciseId) return log;
      }
    }
    return null;
  }

  void updateSet(int exerciseIndex, int setIndex, LoggedSet value) {
    final data = state.requireValue;
    final session = data.activeSession!;
    final exercises = [...session.exercises];
    final sets = [...exercises[exerciseIndex].sets]..[setIndex] = value;
    exercises[exerciseIndex] = exercises[exerciseIndex].copyWith(sets: sets);
    _set(data.copyWith(activeSession: session.copyWith(exercises: exercises)));
  }

  void addSet(int exerciseIndex) {
    final data = state.requireValue;
    final session = data.activeSession!;
    final exercises = [...session.exercises];
    final sets = [...exercises[exerciseIndex].sets];
    final last = sets.isEmpty ? null : sets.last;
    sets.add(LoggedSet(
        id: _uuid.v4(),
        weightKg: last?.weightKg ?? 0,
        reps: last?.reps ?? 8,
        seconds: last?.seconds ?? 0,
        distanceM: last?.distanceM ?? 0));
    exercises[exerciseIndex] = exercises[exerciseIndex].copyWith(sets: sets);
    _set(data.copyWith(activeSession: session.copyWith(exercises: exercises)));
  }

  void removeSet(int exerciseIndex, int setIndex) {
    final data = state.requireValue;
    final session = data.activeSession!;
    final exercises = [...session.exercises];
    final sets = [...exercises[exerciseIndex].sets]..removeAt(setIndex);
    exercises[exerciseIndex] = exercises[exerciseIndex].copyWith(sets: sets);
    _set(data.copyWith(activeSession: session.copyWith(exercises: exercises)));
  }

  void insertExerciseIntoWorkout(String exerciseId, {int? afterIndex}) {
    final data = state.requireValue;
    final session = data.activeSession;
    if (session == null ||
        !data.exercises.any((exercise) => exercise.id == exerciseId)) return;
    final previous = _previousLog(exerciseId);
    final sets = List.generate(3, (index) {
      final old = previous != null &&
              index < previous.sets.length &&
              previous.sets[index].completed
          ? previous.sets[index]
          : null;
      return LoggedSet(
        id: _uuid.v4(),
        weightKg: old?.weightKg ?? 0,
        reps: old?.reps ?? 8,
        seconds: old?.seconds ?? 0,
        distanceM: old?.distanceM ?? 0,
      );
    });
    final exercises = [...session.exercises];
    final insertion = afterIndex == null
        ? exercises.length
        : (afterIndex + 1).clamp(0, exercises.length);
    exercises.insert(
      insertion,
      ExerciseLog(
        id: _uuid.v4(),
        exerciseId: exerciseId,
        sets: sets,
      ),
    );
    _set(data.copyWith(activeSession: session.copyWith(exercises: exercises)));
  }

  void removeExerciseFromWorkout(int exerciseIndex) {
    final data = state.requireValue;
    final session = data.activeSession;
    if (session == null ||
        exerciseIndex < 0 ||
        exerciseIndex >= session.exercises.length) return;
    final exercises = [...session.exercises]..removeAt(exerciseIndex);
    _set(data.copyWith(activeSession: session.copyWith(exercises: exercises)));
  }

  void finishWorkout() {
    final data = state.requireValue;
    final done = data.activeSession!.copyWith(completedAt: DateTime.now());
    final advances = data.scheduleMode == ScheduleMode.rolling &&
        done.templateId != null &&
        data.rotation.isNotEmpty &&
        data.rotation[data.rotationIndex % data.rotation.length] ==
            done.templateId;
    _set(data.copyWith(
        sessions: [done, ...data.sessions],
        rotationIndex: advances
            ? (data.rotationIndex + 1) % data.rotation.length
            : data.rotationIndex,
        clearActive: true));
  }

  void discardWorkout() => _set(state.requireValue.copyWith(clearActive: true));
  void skipToday() {
    final d = state.requireValue;
    if (d.scheduleMode == ScheduleMode.rolling && d.rotation.isNotEmpty)
      _set(
          d.copyWith(rotationIndex: (d.rotationIndex + 1) % d.rotation.length));
  }

  void resetRotation() => _set(state.requireValue.copyWith(rotationIndex: 0));

  void setScheduleMode(ScheduleMode mode) =>
      _set(state.requireValue.copyWith(scheduleMode: mode));

  void setWeeklyDay(int weekdayIndex, String? templateId) {
    final d = state.requireValue;
    final week = List<String?>.from(d.weeklySchedule);
    while (week.length < 7) {
      week.add(null);
    }
    week[weekdayIndex] = templateId;
    _set(d.copyWith(weeklySchedule: week.take(7).toList()));
  }

  void addRestToRotation() {
    final d = state.requireValue;
    final rest = d.templates.where((e) => e.isRest).firstOrNull;
    if (rest != null) _set(d.copyWith(rotation: [...d.rotation, rest.id]));
  }

  void moveRotationItem(int index, int direction) {
    final d = state.requireValue;
    final target = index + direction;
    if (target < 0 || target >= d.rotation.length) return;
    final rotation = [...d.rotation];
    final item = rotation.removeAt(index);
    rotation.insert(target, item);
    _set(d.copyWith(rotation: rotation, rotationIndex: 0));
  }

  void removeRotationItem(int index) {
    final d = state.requireValue;
    if (index < 0 || index >= d.rotation.length) return;
    final rotation = [...d.rotation]..removeAt(index);
    _set(d.copyWith(rotation: rotation, rotationIndex: 0));
  }

  void addMeasurement(double kg, double? waist) {
    final d = state.requireValue;
    _set(d.copyWith(measurements: [
      BodyMeasurement(
          id: _uuid.v4(), date: DateTime.now(), weightKg: kg, waistCm: waist),
      ...d.measurements
    ]));
  }

  void addCheckIn(
      int sleep, int energy, int readiness, Map<String, int> soreness) {
    final d = state.requireValue;
    _set(d.copyWith(checkIns: [
      RecoveryCheckIn(
          date: DateTime.now(),
          sleep: sleep,
          energy: energy,
          readiness: readiness,
          soreness: soreness),
      ...d.checkIns
    ]));
  }

  void addTemplate(String name, List<TemplateExercise> exercises) {
    final d = state.requireValue;
    final template =
        WorkoutTemplate(id: _uuid.v4(), name: name, exercises: exercises);
    _set(d.copyWith(
        templates: [...d.templates, template],
        rotation: [...d.rotation, template.id]));
  }

  void updateTemplate(
      String id, String name, List<TemplateExercise> exercises) {
    final data = state.requireValue;
    final original = data.templates.where((t) => t.id == id).firstOrNull;
    if (original == null ||
        original.isRest ||
        name.trim().isEmpty ||
        exercises.isEmpty) return;
    final templates = data.templates
        .map((t) => t.id == id
            ? WorkoutTemplate(id: id, name: name.trim(), exercises: exercises)
            : t)
        .toList();
    _set(data.copyWith(templates: templates));
  }

  void deleteTemplate(String templateId) {
    final d = state.requireValue;
    final template =
        d.templates.where((item) => item.id == templateId).firstOrNull;
    if (template == null || template.isRest) return;
    final currentId = d.rotation.isEmpty
        ? null
        : d.rotation[d.rotationIndex % d.rotation.length];
    final rotation = d.rotation.where((id) => id != templateId).toList();
    var rotationIndex = 0;
    if (rotation.isNotEmpty) {
      if (currentId != null &&
          currentId != templateId &&
          rotation.contains(currentId)) {
        rotationIndex = rotation.indexOf(currentId);
      } else {
        rotationIndex = d.rotationIndex.clamp(0, rotation.length - 1);
      }
    }
    _set(d.copyWith(
      templates: d.templates.where((item) => item.id != templateId).toList(),
      rotation: rotation,
      rotationIndex: rotationIndex,
      weeklySchedule:
          d.weeklySchedule.map((id) => id == templateId ? null : id).toList(),
    ));
  }

  void deleteWorkout(String sessionId) {
    final d = state.requireValue;
    _set(d.copyWith(
        sessions:
            d.sessions.where((session) => session.id != sessionId).toList()));
  }

  void addExercise(String name, String muscle, ExerciseKind kind) {
    final d = state.requireValue;
    _set(d.copyWith(exercises: [
      ...d.exercises,
      Exercise(
          id: _uuid.v4(), name: name, muscle: muscle, kind: kind, custom: true)
    ]));
  }

  void toggleUnits() {
    final d = state.requireValue;
    _set(d.copyWith(useKg: !d.useKg));
  }

  Future<String> exportJson() => _repository.exportJson();
  Future<void> importJson(String raw) async {
    final restored = AppData.decode(raw);
    await _repository.importJson(raw);
    state = AsyncData(restored);
    try {
      await _autoBackup.write(restored.encode());
    } catch (_) {
      // The provider may be offline; a later data change will retry.
    }
  }

  Future<bool> get isAutoBackupEnabled => _autoBackup.isEnabled;

  Future<bool> chooseAutoBackupDestination() async {
    final data = state.requireValue;
    return _autoBackup.chooseDestination(data.encode());
  }

  Future<bool> useExistingAutoBackupDestination() async {
    final data = state.requireValue;
    return _autoBackup.useExistingDestination(data.encode());
  }

  Future<void> disableAutoBackup() => _autoBackup.disable();

  void applyBulkImport(AppData imported) => _set(imported);

  String exportCsv() {
    final rows = ['date,workout,exercise,set,weight_kg,reps,volume'];
    final d = state.requireValue;
    for (final s in d.sessions) {
      for (final e in s.exercises) {
        final name =
            d.exercises.where((x) => x.id == e.exerciseId).firstOrNull?.name ??
                e.exerciseId;
        for (var i = 0; i < e.sets.length; i++) {
          final set = e.sets[i];
          if (set.completed)
            rows.add(
                '${s.startedAt.toIso8601String()},${jsonEncode(s.name)},${jsonEncode(name)},${i + 1},${set.weightKg},${set.reps},${set.volume}');
        }
      }
    }
    return rows.join('\n');
  }
}
