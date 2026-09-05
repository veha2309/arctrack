import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel_community/excel_community.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../domain/models.dart';

class BulkImportResult {
  const BulkImportResult({required this.data, required this.summary});
  final AppData data;
  final String summary;
}

class BulkExcelService {
  static const _uuid = Uuid();
  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  Uint8List createTemplate() {
    final book = Excel.createExcel();
    book.rename('Sheet1', 'Plan');
    final plan = book['Plan'];
    plan.appendRow(_cells([
      'mode',
      'slot',
      'workout',
      'exercise',
      'muscle',
      'type',
      'sets',
      'reps',
      'rest_seconds'
    ]));
    plan.appendRow(_cells([
      'weekly',
      'monday',
      'Upper',
      'Bench Press',
      'Chest',
      'strength',
      4,
      6,
      150
    ]));
    plan.appendRow(_cells([
      'weekly',
      'monday',
      'Upper',
      'Cable Row',
      'Back',
      'strength',
      4,
      8,
      120
    ]));
    plan.appendRow(
        _cells(['weekly', 'tuesday', 'Rest', '', '', '', '', '', '']));
    plan.appendRow(_cells([
      'weekly',
      'wednesday',
      'Lower',
      'Back Squat',
      'Quadriceps',
      'strength',
      4,
      6,
      180
    ]));
    final log = book['History'];
    log.appendRow(_cells([
      'date',
      'workout',
      'exercise',
      'set',
      'weight_kg',
      'reps',
      'completed'
    ]));
    log.appendRow(
        _cells(['2026-09-01 18:00', 'Upper', 'Bench Press', 1, 60, 8, true]));
    final notes = book['Instructions'];
    notes.appendRow(_cells(['ArcTrack bulk import']));
    notes.appendRow(_cells([
      'Use mode "rolling" with numeric slots (1, 2, 3...) or mode "weekly" with weekday slots.'
    ]));
    notes.appendRow(_cells([
      'Use workout "Rest" with an empty exercise to add repeatable rest days.'
    ]));
    notes.appendRow(_cells([
      'Exercise type: strength, bodyweight, timed, or distance. Dates use YYYY-MM-DD HH:MM.'
    ]));
    final encoded = book.encode();
    if (encoded == null)
      throw const FormatException('Could not create workbook');
    return Uint8List.fromList(encoded);
  }

  BulkImportResult import(Uint8List bytes, AppData current) {
    final book = _readWorkbook(bytes);
    if (!book.containsKey('Plan')) {
      throw const FormatException('Missing required "Plan" sheet.');
    }
    final rows = book['Plan']!;
    if (rows.length < 2)
      throw const FormatException('The Plan sheet has no data rows.');
    final header = _header(rows.first);
    for (final required in ['mode', 'slot', 'workout', 'exercise']) {
      if (!header.containsKey(required)) {
        throw FormatException('Plan sheet is missing "$required" column.');
      }
    }

    final exercises = [...current.exercises];
    final grouped = <String, List<TemplateExercise>>{};
    final slots = <String, String>{};
    var mode = current.scheduleMode;
    var importedRows = 0;

    for (final row in rows.skip(1)) {
      final workout = _value(row, header, 'workout');
      if (workout.isEmpty) continue;
      importedRows++;
      final modeText = _value(row, header, 'mode').toLowerCase();
      if (modeText == 'weekly') mode = ScheduleMode.weekly;
      if (modeText == 'rolling') mode = ScheduleMode.rolling;
      final slot = _value(row, header, 'slot').toLowerCase();
      slots[slot] = workout;
      if (workout.toLowerCase() == 'rest') {
        grouped.putIfAbsent('Rest', () => []);
        continue;
      }
      final exerciseName = _value(row, header, 'exercise');
      if (exerciseName.isEmpty) continue;
      var exercise = exercises
          .where((e) => e.name.toLowerCase() == exerciseName.toLowerCase())
          .firstOrNull;
      if (exercise == null) {
        final kindText = _value(row, header, 'type').toLowerCase();
        final kind =
            ExerciseKind.values.where((e) => e.name == kindText).firstOrNull ??
                ExerciseKind.strength;
        exercise = Exercise(
            id: _uuid.v4(),
            name: exerciseName,
            muscle: _value(row, header, 'muscle').isEmpty
                ? 'Other'
                : _value(row, header, 'muscle'),
            kind: kind,
            custom: true);
        exercises.add(exercise);
      }
      grouped.putIfAbsent(workout, () => []).add(TemplateExercise(
          exerciseId: exercise.id,
          sets: _number(row, header, 'sets', 3).round().clamp(1, 20),
          reps: _number(row, header, 'reps', 8).round().clamp(1, 999),
          restSeconds:
              _number(row, header, 'rest_seconds', 90).round().clamp(0, 900)));
    }
    if (importedRows == 0)
      throw const FormatException('No valid Plan rows found.');

    final templates = [...current.templates];
    final nameToId = <String, String>{};
    for (final entry in grouped.entries) {
      final existing = templates
          .where((e) => e.name.toLowerCase() == entry.key.toLowerCase())
          .firstOrNull;
      final id = existing?.id ?? _uuid.v4();
      final replacement = WorkoutTemplate(
          id: id,
          name: entry.key,
          exercises: entry.value,
          isRest: entry.key.toLowerCase() == 'rest');
      if (existing == null) {
        templates.add(replacement);
      } else {
        templates[templates.indexOf(existing)] = replacement;
      }
      nameToId[entry.key.toLowerCase()] = id;
    }

    var rotation = current.rotation;
    var weekly = List<String?>.filled(7, null);
    if (mode == ScheduleMode.weekly) {
      for (final entry in slots.entries) {
        final index = _days.indexOf(entry.key);
        if (index >= 0) weekly[index] = nameToId[entry.value.toLowerCase()];
      }
    } else {
      final ordered = slots.entries.toList()
        ..sort((a, b) =>
            (int.tryParse(a.key) ?? 999).compareTo(int.tryParse(b.key) ?? 999));
      rotation = ordered
          .map((e) => nameToId[e.value.toLowerCase()])
          .whereType<String>()
          .toList();
    }

    final existingSessionKeys = current.sessions
        .map((s) => '${s.startedAt.toIso8601String()}|${s.name.toLowerCase()}')
        .toSet();
    final importedSessions = _history(book, exercises)
        .where((s) => existingSessionKeys
            .add('${s.startedAt.toIso8601String()}|${s.name.toLowerCase()}'))
        .toList();
    final sessions = [...current.sessions, ...importedSessions];
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return BulkImportResult(
        data: current.copyWith(
            exercises: exercises,
            templates: templates,
            rotation: rotation,
            rotationIndex: 0,
            scheduleMode: mode,
            weeklySchedule: weekly,
            sessions: sessions),
        summary:
            '${grouped.length} workouts, ${exercises.length - current.exercises.length} new exercises, ${sessions.length - current.sessions.length} history entries');
  }

  List<WorkoutSession> _history(
      Map<String, List<List<Object?>>> book, List<Exercise> exercises) {
    final rows = book['History'];
    if (rows == null || rows.length < 2) return [];
    final header = _header(rows.first);
    final grouped = <String, List<List<Object?>>>{};
    for (final row in rows.skip(1)) {
      final date = _value(row, header, 'date');
      final workout = _value(row, header, 'workout');
      if (date.isNotEmpty && workout.isNotEmpty) {
        grouped.putIfAbsent('$date|$workout', () => []).add(row);
      }
    }
    return grouped.entries.map((entry) {
      final first = entry.value.first;
      final date =
          DateTime.tryParse(_value(first, header, 'date')) ?? DateTime.now();
      final workout = _value(first, header, 'workout');
      final exerciseGroups = <String, List<LoggedSet>>{};
      for (final row in entry.value) {
        final exerciseName = _value(row, header, 'exercise');
        if (exerciseName.isEmpty) continue;
        var exercise = exercises
            .where((e) => e.name.toLowerCase() == exerciseName.toLowerCase())
            .firstOrNull;
        if (exercise == null) {
          exercise = Exercise(
              id: _uuid.v4(),
              name: exerciseName,
              muscle: 'Other',
              custom: true);
          exercises.add(exercise);
        }
        exerciseGroups.putIfAbsent(exercise.id, () => []).add(LoggedSet(
            id: _uuid.v4(),
            weightKg: _number(row, header, 'weight_kg', 0),
            reps: _number(row, header, 'reps', 0).round(),
            completed:
                _value(row, header, 'completed').toLowerCase() != 'false'));
      }
      return WorkoutSession(
          id: _uuid.v4(),
          name: workout,
          startedAt: date,
          completedAt: date,
          exercises: exerciseGroups.entries
              .map((e) =>
                  ExerciseLog(id: _uuid.v4(), exerciseId: e.key, sets: e.value))
              .toList());
    }).toList();
  }

  static List<CellValue> _cells(List<Object> values) => values
      .map((v) => v is num
          ? DoubleCellValue(v.toDouble())
          : v is bool
              ? BoolCellValue(v)
              : TextCellValue(v.toString()))
      .toList();
  static Map<String, int> _header(List<Object?> row) => {
        for (var i = 0; i < row.length; i++)
          (row[i]?.toString() ?? '').trim().toLowerCase(): i
      };
  static String _value(List<Object?> row, Map<String, int> header, String key) {
    final index = header[key];
    if (index == null || index >= row.length) return '';
    return (row[index]?.toString() ?? '').trim();
  }

  static double _number(List<Object?> row, Map<String, int> header, String key,
          double fallback) =>
      double.tryParse(_value(row, header, key)) ?? fallback;

  /// Bulk import reads cell values directly from the XLSX package and ignores
  /// styles. A valid data workbook should not fail because an editor emitted a
  /// style variant unsupported by a higher-level parser.
  static Map<String, List<List<Object?>>> _readWorkbook(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    Uint8List entry(String name) {
      final file = archive.findFile(name);
      if (file == null) throw FormatException('Workbook is missing $name.');
      return file.readBytes()!;
    }

    final shared = <String>[];
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedFile != null) {
      final document = XmlDocument.parse(utf8.decode(sharedFile.readBytes()!));
      for (final item in _descendants(document, 'si')) {
        shared.add(_descendants(item, 't').map((e) => e.innerText).join());
      }
    }

    final relationships = <String, String>{};
    final rels =
        XmlDocument.parse(utf8.decode(entry('xl/_rels/workbook.xml.rels')));
    for (final relation in _descendants(rels, 'Relationship')) {
      final id = relation.getAttribute('Id');
      final target = relation.getAttribute('Target');
      if (id != null && target != null) relationships[id] = target;
    }

    final result = <String, List<List<Object?>>>{};
    final workbook = XmlDocument.parse(utf8.decode(entry('xl/workbook.xml')));
    for (final sheet in _descendants(workbook, 'sheet')) {
      final name = sheet.getAttribute('name');
      final relationshipId = sheet.attributes
          .where((a) => a.name.local == 'id')
          .map((a) => a.value)
          .firstOrNull;
      final target =
          relationshipId == null ? null : relationships[relationshipId];
      if (name == null || target == null) continue;
      final normalized = target.startsWith('/')
          ? target.substring(1)
          : target.startsWith('xl/')
              ? target
              : 'xl/$target';
      final xml = XmlDocument.parse(utf8.decode(entry(normalized)));
      final rows = <List<Object?>>[];
      for (final rowElement in _descendants(xml, 'row')) {
        final row = <Object?>[];
        for (final cell in _children(rowElement, 'c')) {
          final reference = cell.getAttribute('r') ?? 'A1';
          final column = _columnIndex(reference);
          while (row.length <= column) {
            row.add(null);
          }
          final type = cell.getAttribute('t');
          final raw = type == 'inlineStr'
              ? _descendants(cell, 't').map((e) => e.innerText).join()
              : _children(cell, 'v').firstOrNull?.innerText ?? '';
          if (type == 's') {
            final index = int.tryParse(raw);
            row[column] =
                index != null && index < shared.length ? shared[index] : raw;
          } else if (type == 'b') {
            row[column] = raw == '1';
          } else if (type == 'inlineStr' || type == 'str') {
            row[column] = raw;
          } else {
            row[column] = num.tryParse(raw) ?? raw;
          }
        }
        rows.add(row);
      }
      result[name] = rows;
    }
    return result;
  }

  static int _columnIndex(String reference) {
    var result = 0;
    for (final unit in reference.codeUnits) {
      if (unit < 65 || unit > 90) break;
      result = result * 26 + unit - 64;
    }
    return result - 1;
  }

  static Iterable<XmlElement> _descendants(XmlNode node, String local) =>
      node.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == local);

  static Iterable<XmlElement> _children(XmlNode node, String local) =>
      node.children
          .whereType<XmlElement>()
          .where((element) => element.name.local == local);
}
