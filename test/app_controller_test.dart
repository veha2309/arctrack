import 'package:arctrack/application/app_controller.dart';
import 'package:arctrack/data/app_repository.dart';
import 'package:arctrack/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exercise can be inserted and removed during an active workout',
      () async {
    final repository = _MemoryRepository(seedData());
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);

    controller.startTemplate(seedData().templates.first);
    controller.insertExerciseIntoWorkout('curl', afterIndex: 0);
    var active =
        container.read(appControllerProvider).requireValue.activeSession!;
    expect(active.exercises[1].exerciseId, 'curl');
    expect(active.exercises[1].sets, hasLength(3));

    controller.removeExerciseFromWorkout(1);
    active = container.read(appControllerProvider).requireValue.activeSession!;
    expect(active.exercises.any((log) => log.exerciseId == 'curl'), isFalse);
  });

  test('deleting a routine cleans schedules but keeps workout history',
      () async {
    final completed = WorkoutSession(
      id: 'completed-push',
      name: 'Push',
      startedAt: DateTime.utc(2026, 1, 1),
      completedAt: DateTime.utc(2026, 1, 1, 1),
      templateId: 'push',
      exercises: const [],
    );
    final initial = seedData().copyWith(
      sessions: [completed],
      weeklySchedule: const ['push', null, null, null, null, null, null],
    );
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(initial)),
    ]);
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);

    controller.deleteTemplate('push');
    var data = container.read(appControllerProvider).requireValue;
    expect(data.templates.any((item) => item.id == 'push'), isFalse);
    expect(data.rotation.contains('push'), isFalse);
    expect(data.weeklySchedule.first, isNull);
    expect(data.sessions.single.id, 'completed-push');

    controller.deleteWorkout('completed-push');
    data = container.read(appControllerProvider).requireValue;
    expect(data.sessions, isEmpty);
  });

  test('timed and distance values carry into the next workout', () async {
    final previous = WorkoutSession(
      id: 'previous',
      name: 'Cardio',
      startedAt: DateTime(2026, 9, 1),
      completedAt: DateTime(2026, 9, 1),
      exercises: const [
        ExerciseLog(id: 'timed', exerciseId: 'plank', sets: [
          LoggedSet(id: 'one', seconds: 75, completed: true),
        ]),
        ExerciseLog(id: 'distance', exerciseId: 'run', sets: [
          LoggedSet(id: 'two', distanceM: 3200, completed: true),
        ]),
      ],
    );
    final initial = seedData().copyWith(sessions: [previous]);
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(_MemoryRepository(initial)),
    ]);
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    container
        .read(appControllerProvider.notifier)
        .startTemplate(const WorkoutTemplate(
          id: 'cardio',
          name: 'Cardio',
          exercises: [
            TemplateExercise(exerciseId: 'plank', sets: 1),
            TemplateExercise(exerciseId: 'run', sets: 1),
          ],
        ));
    final logs = container
        .read(appControllerProvider)
        .requireValue
        .activeSession!
        .exercises;
    expect(logs[0].sets.single.seconds, 75);
    expect(logs[1].sets.single.distanceM, 3200);
  });

  test('editing a routine retains its identity and historical workouts',
      () async {
    final previous = WorkoutSession(
        id: 'old',
        name: 'Push',
        startedAt: DateTime(2026, 1, 1),
        completedAt: DateTime(2026, 1, 1),
        templateId: 'push',
        exercises: const []);
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(
          _MemoryRepository(seedData().copyWith(sessions: [previous]))),
    ]);
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    container.read(appControllerProvider.notifier).updateTemplate('push',
        'Push A', const [TemplateExercise(exerciseId: 'bench', sets: 5)]);
    final result = container.read(appControllerProvider).requireValue;
    expect(result.templates.first.id, 'push');
    expect(result.templates.first.name, 'Push A');
    expect(result.templates.first.exercises.single.sets, 5);
    expect(result.sessions.single.id, 'old');
    expect(result.rotation.first, 'push');
  });
}

class _MemoryRepository implements AppRepository {
  _MemoryRepository(this.data);
  AppData data;

  @override
  Future<String> exportJson() async => data.encode();

  @override
  Future<void> importJson(String raw) async => data = AppData.decode(raw);

  @override
  Future<AppData?> load() async => data;

  @override
  Future<void> save(AppData data) async => this.data = data;
}
