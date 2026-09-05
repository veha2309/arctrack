import 'package:arctrack/data/app_repository.dart';
import 'package:arctrack/data/bulk_excel.dart';
import 'package:arctrack/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout volume and working sets use completed sets', () {
    final session = WorkoutSession(
      id: 's',
      name: 'Push',
      startedAt: _fixedDate,
      exercises: [
        ExerciseLog(id: 'l', exerciseId: 'bench', sets: [
          LoggedSet(id: '1', weightKg: 20, reps: 10, completed: true),
          LoggedSet(
              id: '2',
              weightKg: 10,
              reps: 10,
              completed: true,
              kind: SetKind.warmup),
          LoggedSet(id: '3', weightKg: 40, reps: 5),
        ]),
      ],
    );
    expect(session.volume, 300);
    expect(session.workingSets, 1);
  });

  test('JSON backup preserves rotation and active workout', () {
    final source = seedData().copyWith(
      rotationIndex: 2,
      activeSession: WorkoutSession(
          id: 'active', name: 'Legs', startedAt: _fixedDate, exercises: []),
    );
    final decoded = AppData.decode(source.encode());
    expect(decoded.rotationIndex, 2);
    expect(decoded.todayTemplate?.name, 'Legs');
    expect(decoded.activeSession?.id, 'active');
  });

  test('recovery score penalizes soreness and stays bounded', () {
    final recovered = RecoveryCheckIn(
        date: _fixedDate, sleep: 5, energy: 5, readiness: 5, soreness: {});
    final sore = RecoveryCheckIn(
        date: _fixedDate,
        sleep: 5,
        energy: 5,
        readiness: 5,
        soreness: {'Legs': 5, 'Back': 5});
    expect(recovered.score, 100);
    expect(sore.score, lessThan(recovered.score));
    expect(sore.score, inInclusiveRange(0, 100));
  });

  test('old backups default to rolling schedule mode', () {
    final original = seedData();
    final raw = original
        .encode()
        .replaceFirst('"scheduleMode":"rolling",', '')
        .replaceFirst(
            '"weeklySchedule":[null,null,null,null,null,null,null],', '');
    final decoded = AppData.decode(raw);
    expect(decoded.scheduleMode, ScheduleMode.rolling);
    expect(decoded.weeklySchedule, hasLength(7));
  });

  test('Excel template imports a fixed weekly split and history', () {
    final service = BulkExcelService();
    final result = service.import(service.createTemplate(), seedData());
    expect(result.data.scheduleMode, ScheduleMode.weekly);
    expect(result.data.weeklySchedule[0], isNotNull);
    expect(result.data.templates.any((e) => e.name == 'Upper'), isTrue);
    expect(result.data.sessions, isNotEmpty);
  });

  test('weight and length unit conversions round trip', () {
    expect(weightForDisplay(100, false), closeTo(220.462, 0.001));
    expect(weightToKilograms(weightForDisplay(100, false), false),
        closeTo(100, 0.0001));
    expect(lengthForDisplay(100, false), closeTo(39.37, 0.001));
    expect(lengthToCentimeters(lengthForDisplay(100, false), false),
        closeTo(100, 0.0001));
  });

  test('exercise rest duration survives backup round trip', () {
    final source = seedData().copyWith(
      activeSession: WorkoutSession(
        id: 'active',
        name: 'Push',
        startedAt: _fixedDate,
        exercises: const [
          ExerciseLog(
              id: 'log', exerciseId: 'bench', sets: [], restSeconds: 150),
        ],
      ),
    );
    final decoded = AppData.decode(source.encode());
    expect(decoded.activeSession!.exercises.single.restSeconds, 150);
  });

  test('reimporting the same workbook does not duplicate history', () {
    final service = BulkExcelService();
    final bytes = service.createTemplate();
    final first = service.import(bytes, seedData()).data;
    final second = service.import(bytes, first).data;
    expect(second.sessions.length, first.sessions.length);
  });
}

final _fixedDate = DateTime.utc(2026, 1, 1);
