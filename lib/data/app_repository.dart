import '../domain/models.dart';
import 'app_database.dart';

abstract interface class AppRepository {
  Future<AppData?> load();
  Future<void> save(AppData data);
  Future<String> exportJson();
  Future<void> importJson(String raw);
}

class LocalAppRepository implements AppRepository {
  LocalAppRepository(this.database);
  final ArcDatabase database;

  @override
  Future<AppData?> load() async {
    final raw = await database.loadPayload();
    return raw == null ? null : AppData.decode(raw);
  }

  @override
  Future<void> save(AppData data) => database.savePayload(data.encode());

  @override
  Future<String> exportJson() async =>
      (await database.loadPayload()) ?? seedData().encode();

  @override
  Future<void> importJson(String raw) async {
    final parsed = AppData.decode(raw);
    await save(parsed);
  }
}

AppData seedData() {
  const exercises = [
    Exercise(id: 'bench', name: 'Barbell Bench Press', muscle: 'Chest'),
    Exercise(id: 'ohp', name: 'Overhead Press', muscle: 'Shoulders'),
    Exercise(id: 'incline_db', name: 'Incline Dumbbell Press', muscle: 'Chest'),
    Exercise(id: 'lateral_raise', name: 'Lateral Raise', muscle: 'Shoulders'),
    Exercise(id: 'triceps', name: 'Cable Triceps Extension', muscle: 'Triceps'),
    Exercise(id: 'deadlift', name: 'Deadlift', muscle: 'Back'),
    Exercise(id: 'pulldown', name: 'Lat Pulldown', muscle: 'Back'),
    Exercise(id: 'row', name: 'Seated Cable Row', muscle: 'Back'),
    Exercise(id: 'curl', name: 'Dumbbell Curl', muscle: 'Biceps'),
    Exercise(id: 'squat', name: 'Back Squat', muscle: 'Quadriceps'),
    Exercise(id: 'rdl', name: 'Romanian Deadlift', muscle: 'Hamstrings'),
    Exercise(id: 'leg_press', name: 'Leg Press', muscle: 'Quadriceps'),
    Exercise(id: 'calf', name: 'Standing Calf Raise', muscle: 'Calves'),
    Exercise(
        id: 'pullup',
        name: 'Pull-up',
        muscle: 'Back',
        kind: ExerciseKind.bodyweight),
    Exercise(
        id: 'plank', name: 'Plank', muscle: 'Core', kind: ExerciseKind.timed),
    Exercise(
        id: 'run',
        name: 'Treadmill Run',
        muscle: 'Cardio',
        kind: ExerciseKind.distance),
  ];
  const push = WorkoutTemplate(id: 'push', name: 'Push', exercises: [
    TemplateExercise(exerciseId: 'bench', sets: 4, reps: 6, restSeconds: 150),
    TemplateExercise(exerciseId: 'ohp', sets: 3, reps: 8, restSeconds: 120),
    TemplateExercise(exerciseId: 'incline_db', sets: 3, reps: 10),
    TemplateExercise(
        exerciseId: 'lateral_raise', sets: 3, reps: 15, restSeconds: 60),
    TemplateExercise(exerciseId: 'triceps', sets: 3, reps: 12, restSeconds: 60),
  ]);
  const pull = WorkoutTemplate(id: 'pull', name: 'Pull', exercises: [
    TemplateExercise(
        exerciseId: 'deadlift', sets: 3, reps: 5, restSeconds: 180),
    TemplateExercise(exerciseId: 'pulldown', sets: 3, reps: 10),
    TemplateExercise(exerciseId: 'row', sets: 3, reps: 10),
    TemplateExercise(exerciseId: 'curl', sets: 3, reps: 12, restSeconds: 60),
  ]);
  const legs = WorkoutTemplate(id: 'legs', name: 'Legs', exercises: [
    TemplateExercise(exerciseId: 'squat', sets: 4, reps: 6, restSeconds: 180),
    TemplateExercise(exerciseId: 'rdl', sets: 3, reps: 8, restSeconds: 150),
    TemplateExercise(exerciseId: 'leg_press', sets: 3, reps: 12),
    TemplateExercise(exerciseId: 'calf', sets: 4, reps: 15, restSeconds: 60),
  ]);
  const rest =
      WorkoutTemplate(id: 'rest', name: 'Rest', exercises: [], isRest: true);
  return const AppData(
      exercises: exercises,
      templates: [push, pull, legs, rest],
      rotation: ['push', 'pull', 'legs', 'rest'],
      rotationIndex: 0,
      sessions: [],
      measurements: [],
      checkIns: []);
}
