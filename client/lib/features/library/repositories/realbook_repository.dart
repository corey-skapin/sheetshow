import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/features/library/models/realbook_model.dart';

/// Repository for managing realbook records and their tags.
class RealbookRepository {
  RealbookRepository(this._db, this._clock);

  final AppDatabase _db;
  final ClockService _clock;

  // ─── Read ──────────────────────────────────────────────────────────────────

  /// Get all realbooks with their score counts.
  Future<List<RealbookModel>> getAll() async {
    final rows = await _db.customSelect('''
      SELECT r.*, (
        SELECT COUNT(*) FROM scores s WHERE s.realbook_id = r.id
      ) AS score_count
      FROM realbooks r
      ORDER BY r.title COLLATE NOCASE
    ''').get();
    return rows.map(_mapSqlRow).toList();
  }

  /// Get a single realbook by ID.
  Future<RealbookModel?> getById(String id) async {
    final row = await (_db.select(_db.realbooks)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  /// Check if a file path belongs to a known realbook.
  Future<bool> isRealbookPath(String filePath) async {
    final row = await (_db.select(_db.realbooks)
          ..where((r) => r.localFilePath.equals(filePath))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Watch all realbooks as a stream (for reactive UI).
  Stream<List<RealbookModel>> watchAll() {
    return _db
        .customSelect(
          '''
      SELECT r.*, (
        SELECT COUNT(*) FROM scores s WHERE s.realbook_id = r.id
      ) AS score_count
      FROM realbooks r
      ORDER BY r.title COLLATE NOCASE
    ''',
          readsFrom: {_db.realbooks, _db.scores},
        )
        .watch()
        .map((rows) => rows.map(_mapSqlRow).toList());
  }

  // ─── Write ─────────────────────────────────────────────────────────────────

  /// Insert a new realbook.
  Future<void> insert(RealbookModel realbook) async {
    await _db.into(_db.realbooks).insert(
          RealbooksCompanion.insert(
            id: realbook.id,
            title: realbook.title,
            filename: realbook.filename,
            localFilePath: realbook.localFilePath,
            totalPages: realbook.totalPages,
            pageOffset: Value(realbook.pageOffset),
            updatedAt: realbook.updatedAt,
          ),
        );
  }

  /// Update a realbook's title.
  Future<void> updateTitle(String id, String newTitle) async {
    await (_db.update(_db.realbooks)..where((r) => r.id.equals(id))).write(
      RealbooksCompanion(
        title: Value(newTitle),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  /// Delete a realbook and cascade-delete all its scores, annotations, tags,
  /// set list entries, and FTS entries.
  Future<void> delete(String id) async {
    // Clean up FTS entries for all scores in this realbook
    final scoreIds = await _db.customSelect(
      'SELECT id FROM scores WHERE realbook_id = ?',
      variables: [Variable.withString(id)],
    ).get();
    for (final row in scoreIds) {
      final scoreId = row.read<String>('id');
      await _db
          .customStatement('DELETE FROM score_search WHERE id = ?', [scoreId]);
    }
    // CASCADE on the FK handles scores, their tags, memberships,
    // annotations, and set list entries.
    await (_db.delete(_db.realbooks)..where((r) => r.id.equals(id))).go();
  }

  // ─── Tags ──────────────────────────────────────────────────────────────────

  /// Get all tags for a realbook.
  Future<List<String>> getTags(String realbookId) async {
    final rows = await (_db.select(_db.realbookTags)
          ..where((t) => t.realbookId.equals(realbookId)))
        .get();
    return rows.map((r) => r.tag).toList()..sort();
  }

  /// Replace all tags on a realbook with [tags].
  Future<void> setTags(String realbookId, List<String> tags) async {
    await _db.transaction(() async {
      await (_db.delete(_db.realbookTags)
            ..where((t) => t.realbookId.equals(realbookId)))
          .go();
      for (final tag in tags) {
        await _db.into(_db.realbookTags).insert(
              RealbookTagsCompanion.insert(
                realbookId: realbookId,
                tag: tag,
              ),
            );
      }
    });
  }

  // ─── Mapping ───────────────────────────────────────────────────────────────

  RealbookModel _mapRow(Realbook row) => RealbookModel(
        id: row.id,
        title: row.title,
        filename: row.filename,
        localFilePath: row.localFilePath,
        totalPages: row.totalPages,
        pageOffset: row.pageOffset,
        updatedAt: row.updatedAt,
      );

  RealbookModel _mapSqlRow(QueryRow row) => RealbookModel(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        filename: row.read<String>('filename'),
        localFilePath: row.read<String>('local_file_path'),
        totalPages: row.read<int>('total_pages'),
        pageOffset: row.read<int>('page_offset'),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
        scoreCount: row.read<int>('score_count'),
      );
}

/// Riverpod provider for [RealbookRepository].
final realbookRepositoryProvider = Provider<RealbookRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  final clock = ref.watch(clockServiceProvider);
  return RealbookRepository(db, clock);
});
