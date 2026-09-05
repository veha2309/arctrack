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
