import 'dart:convert';

enum ExerciseKind { strength, bodyweight, timed, distance }

enum SetKind { warmup, working, drop, failure }

enum ScheduleMode { rolling, weekly }

const double poundsPerKilogram = 2.2046226218;
const double inchesPerCentimeter = 0.3937007874;

double weightForDisplay(double kilograms, bool useKg) =>
    useKg ? kilograms : kilograms * poundsPerKilogram;

double weightToKilograms(double value, bool useKg) =>
    useKg ? value : value / poundsPerKilogram;

String weightUnit(bool useKg) => useKg ? 'kg' : 'lb';
String lengthUnit(bool useKg) => useKg ? 'cm' : 'in';
String distanceUnit(bool useKg) => useKg ? 'km' : 'mi';
double distanceForDisplay(double meters, bool useKg) =>
    useKg ? meters / 1000 : meters / 1609.344;
double distanceToMeters(double distance, bool useKg) =>
    distance * (useKg ? 1000 : 1609.344);

double lengthForDisplay(double centimeters, bool useKg) =>
    useKg ? centimeters : centimeters * inchesPerCentimeter;

double lengthToCentimeters(double value, bool useKg) =>
    useKg ? value : value / inchesPerCentimeter;

String formatWeight(double kilograms, bool useKg) {
  final value = weightForDisplay(kilograms, useKg);
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class Exercise {
  const Exercise(
      {required this.id,
      required this.name,
      required this.muscle,
      this.kind = ExerciseKind.strength,
      this.custom = false});
  final String id;
  final String name;
  final String muscle;
  final ExerciseKind kind;
  final bool custom;
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'muscle': muscle,
        'kind': kind.name,
        'custom': custom
      };
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
      id: j['id'],
      name: j['name'],
      muscle: j['muscle'],
      kind: ExerciseKind.values.byName(j['kind'] ?? 'strength'),
      custom: j['custom'] ?? false);
}

class TemplateExercise {
  const TemplateExercise(
      {required this.exerciseId,
      this.sets = 3,
      this.reps = 8,
      this.restSeconds = 90});
  final String exerciseId;
  final int sets;
  final int reps;
  final int restSeconds;
  Map<String, Object?> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds
      };
  factory TemplateExercise.fromJson(Map<String, dynamic> j) => TemplateExercise(
      exerciseId: j['exerciseId'],
      sets: j['sets'] ?? 3,
      reps: j['reps'] ?? 8,
      restSeconds: j['restSeconds'] ?? 90);
}

class WorkoutTemplate {
  const WorkoutTemplate(
      {required this.id,
      required this.name,
      required this.exercises,
      this.isRest = false});
  final String id;
  final String name;
  final List<TemplateExercise> exercises;
  final bool isRest;
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'isRest': isRest,
        'exercises': exercises.map((e) => e.toJson()).toList()
      };
  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
      id: j['id'],
      name: j['name'],
      isRest: j['isRest'] ?? false,
      exercises: (j['exercises'] as List? ?? [])
          .map((e) => TemplateExercise.fromJson(Map<String, dynamic>.from(e)))
          .toList());
}

class LoggedSet {
  const LoggedSet(
      {required this.id,
      this.weightKg = 0,
      this.reps = 0,
      this.seconds = 0,
      this.distanceM = 0,
      this.completed = false,
      this.kind = SetKind.working,
      this.rpe,
      this.rir,
      this.tempo,
      this.notes});
  final String id;
  final double weightKg;
  final int reps;
  final int seconds;
  final double distanceM;
  final bool completed;
  final SetKind kind;
  final double? rpe;
  final int? rir;
  final String? tempo;
  final String? notes;
  double get volume => completed ? weightKg * reps : 0;
  LoggedSet copyWith(
          {double? weightKg,
          int? reps,
          int? seconds,
          double? distanceM,
          bool? completed,
          SetKind? kind,
          double? rpe,
          int? rir,
          String? tempo,
          String? notes}) =>
      LoggedSet(
          id: id,
          weightKg: weightKg ?? this.weightKg,
          reps: reps ?? this.reps,
          seconds: seconds ?? this.seconds,
          distanceM: distanceM ?? this.distanceM,
          completed: completed ?? this.completed,
          kind: kind ?? this.kind,
          rpe: rpe ?? this.rpe,
          rir: rir ?? this.rir,
          tempo: tempo ?? this.tempo,
          notes: notes ?? this.notes);
  Map<String, Object?> toJson() => {
        'id': id,
        'weightKg': weightKg,
        'reps': reps,
        'seconds': seconds,
        'distanceM': distanceM,
        'completed': completed,
        'kind': kind.name,
        'rpe': rpe,
        'rir': rir,
        'tempo': tempo,
        'notes': notes
      };
  factory LoggedSet.fromJson(Map<String, dynamic> j) => LoggedSet(
      id: j['id'],
      weightKg: (j['weightKg'] ?? 0).toDouble(),
      reps: j['reps'] ?? 0,
      seconds: j['seconds'] ?? 0,
      distanceM: (j['distanceM'] ?? 0).toDouble(),
      completed: j['completed'] ?? false,
      kind: SetKind.values.byName(j['kind'] ?? 'working'),
      rpe: (j['rpe'] as num?)?.toDouble(),
      rir: j['rir'],
      tempo: j['tempo'],
      notes: j['notes']);
}

class ExerciseLog {
  const ExerciseLog(
      {required this.id,
      required this.exerciseId,
      required this.sets,
      this.restSeconds = 90,
      this.notes});
  final String id;
  final String exerciseId;
  final List<LoggedSet> sets;
  final int restSeconds;
  final String? notes;
  double get volume => sets.fold(0, (sum, e) => sum + e.volume);
  ExerciseLog copyWith({List<LoggedSet>? sets, String? notes}) => ExerciseLog(
      id: id,
      exerciseId: exerciseId,
      sets: sets ?? this.sets,
      restSeconds: restSeconds,
      notes: notes ?? this.notes);
  Map<String, Object?> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'sets': sets.map((e) => e.toJson()).toList(),
        'restSeconds': restSeconds,
        'notes': notes
      };
  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
      id: j['id'],
      exerciseId: j['exerciseId'],
      sets: (j['sets'] as List)
          .map((e) => LoggedSet.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      restSeconds: j['restSeconds'] ?? 90,
      notes: j['notes']);
}

class WorkoutSession {
  const WorkoutSession(
      {required this.id,
      required this.name,
      required this.startedAt,
      required this.exercises,
      this.completedAt,
      this.templateId});
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? templateId;
  final List<ExerciseLog> exercises;
  bool get complete => completedAt != null;
  double get volume => exercises.fold(0, (sum, e) => sum + e.volume);
  int get workingSets => exercises.fold(
      0,
      (sum, e) =>
          sum +
          e.sets.where((s) => s.completed && s.kind != SetKind.warmup).length);
  WorkoutSession copyWith(
          {List<ExerciseLog>? exercises, DateTime? completedAt}) =>
      WorkoutSession(
          id: id,
          name: name,
          startedAt: startedAt,
          completedAt: completedAt ?? this.completedAt,
          templateId: templateId,
          exercises: exercises ?? this.exercises);
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'templateId': templateId,
        'exercises': exercises.map((e) => e.toJson()).toList()
      };
  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
      id: j['id'],
      name: j['name'],
      startedAt: DateTime.parse(j['startedAt']),
      completedAt:
          j['completedAt'] == null ? null : DateTime.parse(j['completedAt']),
      templateId: j['templateId'],
      exercises: (j['exercises'] as List)
          .map((e) => ExerciseLog.fromJson(Map<String, dynamic>.from(e)))
          .toList());
}

class RecoveryCheckIn {
  const RecoveryCheckIn(
      {required this.date,
      required this.sleep,
      required this.energy,
      required this.readiness,
      required this.soreness});
  final DateTime date;
  final int sleep;
  final int energy;
  final int readiness;
  final Map<String, int> soreness;
  double get score => ((sleep + energy + readiness) / 15 * 100 -
          soreness.values.fold(0, (a, b) => a + b) * 2)
      .clamp(0, 100)
      .toDouble();
  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(),
        'sleep': sleep,
        'energy': energy,
        'readiness': readiness,
        'soreness': soreness
      };
  factory RecoveryCheckIn.fromJson(Map<String, dynamic> j) => RecoveryCheckIn(
      date: DateTime.parse(j['date']),
      sleep: j['sleep'],
      energy: j['energy'],
      readiness: j['readiness'],
      soreness: Map<String, int>.from(j['soreness'] ?? {}));
}

class BodyMeasurement {
  const BodyMeasurement(
      {required this.id,
      required this.date,
      required this.weightKg,
      this.waistCm,
      this.note});
  final String id;
  final DateTime date;
  final double weightKg;
  final double? waistCm;
  final String? note;
  Map<String, Object?> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        'waistCm': waistCm,
        'note': note
      };
  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
      id: j['id'],
      date: DateTime.parse(j['date']),
      weightKg: (j['weightKg'] as num).toDouble(),
      waistCm: (j['waistCm'] as num?)?.toDouble(),
      note: j['note']);
}

class AppData {
  const AppData(
      {required this.exercises,
      required this.templates,
      required this.rotation,
      required this.rotationIndex,
      required this.sessions,
      required this.measurements,
      required this.checkIns,
      this.scheduleMode = ScheduleMode.rolling,
      this.weeklySchedule = const [null, null, null, null, null, null, null],
      this.activeSession,
      this.useKg = true});
  final List<Exercise> exercises;
  final List<WorkoutTemplate> templates;
  final List<String> rotation;
  final int rotationIndex;
  final ScheduleMode scheduleMode;
  final List<String?> weeklySchedule;
  final List<WorkoutSession> sessions;
  final WorkoutSession? activeSession;
  final List<BodyMeasurement> measurements;
  final List<RecoveryCheckIn> checkIns;
  final bool useKg;
  WorkoutTemplate? get todayTemplate {
    final id = scheduleMode == ScheduleMode.weekly
        ? (weeklySchedule.length == 7
            ? weeklySchedule[DateTime.now().weekday - 1]
            : null)
        : (rotation.isEmpty ? null : rotation[rotationIndex % rotation.length]);
    return id == null ? null : templates.where((e) => e.id == id).firstOrNull;
  }

  AppData copyWith(
          {List<Exercise>? exercises,
          List<WorkoutTemplate>? templates,
          List<String>? rotation,
          int? rotationIndex,
          ScheduleMode? scheduleMode,
          List<String?>? weeklySchedule,
          List<WorkoutSession>? sessions,
          WorkoutSession? activeSession,
          bool clearActive = false,
          List<BodyMeasurement>? measurements,
          List<RecoveryCheckIn>? checkIns,
          bool? useKg}) =>
      AppData(
          exercises: exercises ?? this.exercises,
          templates: templates ?? this.templates,
          rotation: rotation ?? this.rotation,
          rotationIndex: rotationIndex ?? this.rotationIndex,
          scheduleMode: scheduleMode ?? this.scheduleMode,
          weeklySchedule: weeklySchedule ?? this.weeklySchedule,
          sessions: sessions ?? this.sessions,
          activeSession:
              clearActive ? null : activeSession ?? this.activeSession,
          measurements: measurements ?? this.measurements,
          checkIns: checkIns ?? this.checkIns,
          useKg: useKg ?? this.useKg);
  Map<String, Object?> toJson() => {
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'templates': templates.map((e) => e.toJson()).toList(),
        'rotation': rotation,
        'rotationIndex': rotationIndex,
        'scheduleMode': scheduleMode.name,
        'weeklySchedule': weeklySchedule,
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'activeSession': activeSession?.toJson(),
        'measurements': measurements.map((e) => e.toJson()).toList(),
        'checkIns': checkIns.map((e) => e.toJson()).toList(),
        'useKg': useKg
      };
  String encode() => jsonEncode(toJson());
  factory AppData.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return AppData(
        exercises: (j['exercises'] as List)
            .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        templates: (j['templates'] as List)
            .map((e) => WorkoutTemplate.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        rotation: List<String>.from(j['rotation']),
        rotationIndex: j['rotationIndex'] ?? 0,
        scheduleMode:
            ScheduleMode.values.byName(j['scheduleMode'] ?? 'rolling'),
        weeklySchedule: (j['weeklySchedule'] as List? ??
                const [null, null, null, null, null, null, null])
            .map((e) => e as String?)
            .toList(),
        sessions: (j['sessions'] as List)
            .map((e) => WorkoutSession.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        activeSession: j['activeSession'] == null
            ? null
            : WorkoutSession.fromJson(
                Map<String, dynamic>.from(j['activeSession'])),
        measurements: (j['measurements'] as List? ?? [])
            .map((e) => BodyMeasurement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        checkIns: (j['checkIns'] as List? ?? [])
            .map((e) => RecoveryCheckIn.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        useKg: j['useKg'] ?? true);
  }
}

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
