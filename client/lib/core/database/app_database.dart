import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';

// T015 + T016: Complete Drift schema for all 8 tables + FTS5 virtual table.
// WAL mode is enabled for SC-008 crash safety.

part 'app_database.g.dart';

// ─── Table definitions ───────────────────────────────────────────────────────

class Scores extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get filename => text()();
  TextColumn get localFilePath => text()();
  IntColumn get totalPages => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get folderId => text().nullable()();
  DateTimeColumn get importedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync fields
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(const Constant('synced'))();
  TextColumn get cloudId => text().nullable()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentFolderId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync fields
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(const Constant('synced'))();
  TextColumn get cloudId => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ScoreTags extends Table {
  TextColumn get scoreId => text().references(Scores, #id)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {scoreId, tag};
}

class SetLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync fields
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(const Constant('synced'))();
  TextColumn get cloudId => text().nullable()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class SetListEntries extends Table {
  TextColumn get id => text()();
  TextColumn get setListId => text().references(SetLists, #id)();
  TextColumn get scoreId => text().references(Scores, #id)();
  IntColumn get orderIndex => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {setListId, orderIndex},
      ];
}

@DataClassName('AnnotationLayerRow')
class AnnotationLayers extends Table {
  TextColumn get id => text()();
  TextColumn get scoreId => text().references(Scores, #id)();
  IntColumn get pageNumber => integer()();
  TextColumn get strokesJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync fields
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(const Constant('synced'))();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {scoreId, pageNumber},
      ];
}

class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => textEnum<SyncEntityType>()();
  TextColumn get entityId => text()();
  TextColumn get operation => textEnum<SyncOperationType>()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── FTS5 virtual table ───────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Scores,
    Folders,
    ScoreTags,
    SetLists,
    SetListEntries,
    AnnotationLayers,
    SyncQueue,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Create FTS5 virtual table for full-text search
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS score_search
            USING fts5(
              id UNINDEXED,
              title,
              tags_flat,
              content='scores',
              content_rowid='rowid'
            )
          ''');
        },
        beforeOpen: (details) async {
          // Enable WAL mode for SC-008 crash safety
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );

  // ─── FTS5 helpers ──────────────────────────────────────────────────────────

  /// Upsert the FTS5 index entry for a score.
  Future<void> rebuildScoreSearch(
    String id,
    String title,
    String tagsFlat,
  ) async {
    await customStatement(
      'DELETE FROM score_search WHERE id = ?',
      [id],
    );
    await customStatement(
      'INSERT INTO score_search(id, title, tags_flat) VALUES (?, ?, ?)',
      [id, title, tagsFlat],
    );
  }

  /// Full-text search across title and tags_flat.
  Future<List<String>> searchScoreIds(String query) async {
    final rows = await customSelect(
      "SELECT id FROM score_search WHERE score_search MATCH ? ORDER BY rank",
      variables: [Variable.withString(query)],
    ).get();
    return rows.map((r) => r.read<String>('id')).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return driftDatabase(name: 'sheetshow.db');
  });
}

/// Riverpod provider for the [AppDatabase] singleton.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
