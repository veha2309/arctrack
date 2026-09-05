import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ArcDatabase extends GeneratedDatabase {
  ArcDatabase() : super(_open());

  static QueryExecutor _open() => LazyDatabase(() async {
        final dir = await getApplicationDocumentsDirectory();
        return NativeDatabase.createInBackground(
          File(p.join(dir.path, 'arctrack.sqlite')),
        );
      });

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => customStatement(
            'CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL, updated_at INTEGER NOT NULL)'),
      );

  Future<String?> loadPayload() async {
    final rows =
        await customSelect('SELECT payload FROM app_state WHERE id = 1').get();
    return rows.isEmpty ? null : rows.first.read<String>('payload');
  }

  Future<void> savePayload(String payload) => customStatement(
        'INSERT INTO app_state (id, payload, updated_at) VALUES (1, ?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at',
        [payload, DateTime.now().millisecondsSinceEpoch],
      );
}
