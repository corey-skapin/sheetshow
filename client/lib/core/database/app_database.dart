import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

// ─── Table definitions ───────────────────────────────────────────────────────

class Scores extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get filename => text()();
  TextColumn get localFilePath => text()();
  IntColumn get totalPages => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentFolderId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ScoreTags extends Table {
  TextColumn get scoreId => text().references(Scores, #id)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {scoreId, tag};
}

class ScoreFolderMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get scoreId =>
      text().references(Scores, #id, onDelete: KeyAction.cascade)();
  TextColumn get folderId =>
      text().references(Folders, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {scoreId, folderId},
      ];
}

class FolderTags extends Table {
  TextColumn get folderId =>
      text().references(Folders, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {folderId, tag};
}

class SetLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {scoreId, pageNumber},
      ];
}

// ─── FTS5 virtual table ───────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Scores,
    Folders,
    ScoreTags,
    FolderTags,
    ScoreFolderMemberships,
    SetLists,
    SetListEntries,
    AnnotationLayers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Create standalone FTS5 virtual table for full-text search
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS score_search
            USING fts5(
              id UNINDEXED,
              title,
              tags_flat
            )
          ''');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Drop sync infrastructure tables
            await customStatement('DROP TABLE IF EXISTS sync_queue');
            await customStatement('DROP TABLE IF EXISTS sync_meta');
            // Drop sync columns from core tables
            await customStatement('ALTER TABLE scores DROP COLUMN sync_state');
            await customStatement('ALTER TABLE scores DROP COLUMN cloud_id');
            await customStatement(
                'ALTER TABLE scores DROP COLUMN server_version');
            await customStatement('ALTER TABLE scores DROP COLUMN is_deleted');
            await customStatement('ALTER TABLE folders DROP COLUMN sync_state');
            await customStatement('ALTER TABLE folders DROP COLUMN cloud_id');
            await customStatement('ALTER TABLE folders DROP COLUMN is_deleted');
            await customStatement(
                'ALTER TABLE set_lists DROP COLUMN sync_state');
            await customStatement('ALTER TABLE set_lists DROP COLUMN cloud_id');
            await customStatement(
                'ALTER TABLE set_lists DROP COLUMN server_version');
            await customStatement(
                'ALTER TABLE set_lists DROP COLUMN is_deleted');
            await customStatement(
                'ALTER TABLE annotation_layers DROP COLUMN sync_state');
            await customStatement(
                'ALTER TABLE annotation_layers DROP COLUMN server_version');
            // Recreate score_search as standalone FTS5 (was content FTS5)
            await customStatement('DROP TABLE IF EXISTS score_search');
            await customStatement('''
              CREATE VIRTUAL TABLE score_search
              USING fts5(
                id UNINDEXED,
                title,
                tags_flat
              )
            ''');
            // Rebuild FTS index from existing scores
            await customStatement(
                'INSERT INTO score_search(id, title, tags_flat) SELECT id, title, \'\' FROM scores');
          }
          if (from < 3) {
            await customStatement('''
              CREATE TABLE folder_tags (
                folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
                tag TEXT NOT NULL,
                PRIMARY KEY (folder_id, tag)
              )
            ''');
            await customStatement('''
              CREATE TABLE score_folder_memberships (
                id TEXT NOT NULL PRIMARY KEY,
                score_id TEXT NOT NULL REFERENCES scores(id) ON DELETE CASCADE,
                folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
                UNIQUE (score_id, folder_id)
              )
            ''');
            await customStatement('''
              INSERT INTO score_folder_memberships(id, score_id, folder_id)
              SELECT id || '-' || folder_id, id, folder_id
              FROM scores WHERE folder_id IS NOT NULL
            ''');
          }
          if (from < 4) {
            await customStatement('ALTER TABLE scores DROP COLUMN folder_id');
            await customStatement('ALTER TABLE scores DROP COLUMN imported_at');
          }
        },
        beforeOpen: (details) async {
          // Enable WAL mode for crash safety
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );

  // ─── FTS5 helpers ──────────────────────────────────────────────────────────

  /// Upsert the FTS5 index entry for a score (atomic delete + insert).
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
