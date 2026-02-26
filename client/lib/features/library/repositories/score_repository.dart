import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/features/library/models/score_model.dart';

/// Client-side score repository backed by Drift/SQLite.
class ScoreRepository {
  ScoreRepository(this._db, this._clock);

  final AppDatabase _db;
  final ClockService _clock;

  // ─── Watch ────────────────────────────────────────────────────────────────

  // Subquery that returns |-separated effective tags for a score row aliased 's'.
  static const _tagsSubquery = '''
    (SELECT GROUP_CONCAT(tag, '|') FROM (
      SELECT tag FROM score_tags WHERE score_id = s.id
      UNION
      SELECT ft.tag FROM folder_tags ft
      JOIN score_folder_memberships mem ON mem.folder_id = ft.folder_id
      WHERE mem.score_id = s.id
    )) AS tags_flat
  ''';

  static const _scoreColumns = '''
    s.id, s.title, s.filename, s.local_file_path, s.total_pages,
    s.thumbnail_path, s.updated_at
  ''';

  /// Reactive stream of all scores, including their effective tags.
  /// When [folderId] is set, returns scores in that folder AND all its
  /// descendant subfolders (recursive).
  Stream<List<ScoreModel>> watchAll({String? folderId}) {
    final Set<ResultSetImplementation<dynamic, dynamic>> tables = {
      _db.scores,
      _db.scoreTags,
      _db.folderTags,
      _db.scoreFolderMemberships,
      _db.folders,
    };
    if (folderId == null) {
      return _db
          .customSelect(
            'SELECT $_scoreColumns, $_tagsSubquery FROM scores s ORDER BY s.title ASC',
            readsFrom: tables,
          )
          .watch()
          .map((rows) => rows.map(_mapSqlRow).toList());
    }
    return _db
        .customSelect(
          '''
      WITH RECURSIVE subtree(id) AS (
        SELECT id FROM folders WHERE id = ?
        UNION
        SELECT f.id FROM folders f JOIN subtree p ON f.parent_folder_id = p.id
      )
      SELECT $_scoreColumns, $_tagsSubquery
      FROM scores s
      JOIN score_folder_memberships m ON m.score_id = s.id
      JOIN subtree p ON p.id = m.folder_id
      GROUP BY s.id
      ORDER BY s.title ASC
      ''',
          variables: [Variable.withString(folderId)],
          readsFrom: tables,
        )
        .watch()
        .map((rows) => rows.map(_mapSqlRow).toList());
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  Future<ScoreModel?> getById(String id) async {
    final row = await (_db.select(_db.scores)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  /// Returns the first score whose stored filename matches [filename], or null.
  Future<ScoreModel?> getByFilename(String filename) async {
    final row = await (_db.select(_db.scores)
          ..where((s) => s.filename.equals(filename))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  /// Returns the first score whose [ScoreModel.localFilePath] matches [filePath].
  Future<ScoreModel?> getByFilePath(String filePath) async {
    final row = await (_db.select(_db.scores)
          ..where((s) => s.localFilePath.equals(filePath))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  Future<void> insert(ScoreModel score, {String? folderId}) async {
    await _db.into(_db.scores).insert(
          ScoresCompanion.insert(
            id: score.id,
            title: score.title,
            filename: score.filename,
            localFilePath: score.localFilePath,
            totalPages: score.totalPages,
            thumbnailPath: Value(score.thumbnailPath),
            updatedAt: score.updatedAt,
          ),
        );
    if (folderId != null) {
      await _addMembership(score.id, folderId);
    }
    await _db.rebuildScoreSearch(score.id, score.title, '');
  }

  /// Add a score to a folder (creates a membership; score stays in all existing folders).
  Future<void> addToFolder(String scoreId, String folderId) async {
    await _addMembership(scoreId, folderId);
  }

  /// Remove a score from a specific folder (membership only; score is not deleted).
  Future<void> removeFromFolder(String scoreId, String folderId) async {
    await (_db.delete(_db.scoreFolderMemberships)
          ..where(
              (m) => m.scoreId.equals(scoreId) & m.folderId.equals(folderId)))
        .go();
  }

  Future<void> _addMembership(String scoreId, String folderId) async {
    await _db
        .into(_db.scoreFolderMemberships)
        .insertOnConflictUpdate(ScoreFolderMembershipsCompanion.insert(
          id: '${scoreId}_$folderId',
          scoreId: scoreId,
          folderId: folderId,
        ));
  }

  /// Returns the score's own tags merged with tags from all folders it belongs to.
  Future<List<String>> getEffectiveTags(String scoreId) async {
    final own = await getTags(scoreId);
    final folderTagRows = await _db.customSelect(
      '''
      SELECT ft.tag FROM folder_tags ft
      JOIN score_folder_memberships m ON m.folder_id = ft.folder_id
      WHERE m.score_id = ?
      ''',
      variables: [Variable.withString(scoreId)],
    ).get();
    final folderTags = folderTagRows.map((r) => r.read<String>('tag')).toList();
    return {...own, ...folderTags}.toList()..sort();
  }

  /// Updates the score's metadata.
  ///
  /// If [ScoreModel.title] has changed and the file at [ScoreModel.localFilePath]
  /// exists on disk, the file is renamed to match the new title and
  /// [local_file_path] / [filename] are updated in the database accordingly.
  Future<void> update(ScoreModel score) async {
    final existing = await getById(score.id);

    if (existing != null && existing.title != score.title) {
      final oldFile = File(existing.localFilePath);
      if (await oldFile.exists()) {
        final dir = path.dirname(existing.localFilePath);
        final newFilename = '${score.title}.pdf';
        final newPath = path.join(dir, newFilename);
        await oldFile.rename(newPath);
        try {
          await (_db.update(_db.scores)..where((s) => s.id.equals(score.id)))
              .write(ScoresCompanion(
            title: Value(score.title),
            filename: Value(newFilename),
            localFilePath: Value(newPath),
            thumbnailPath: Value(score.thumbnailPath),
            updatedAt: Value(_clock.now()),
          ));
          await _db.rebuildScoreSearch(score.id, score.title, '');
        } catch (e) {
          // Rollback the file rename so filesystem stays consistent with DB.
          await File(newPath).rename(existing.localFilePath);
          rethrow;
        }
        return;
      }
    }

    await (_db.update(_db.scores)..where((s) => s.id.equals(score.id)))
        .write(ScoresCompanion(
      title: Value(score.title),
      thumbnailPath: Value(score.thumbnailPath),
      updatedAt: Value(_clock.now()),
    ));
    await _db.rebuildScoreSearch(score.id, score.title, '');
  }

  /// Updates [local_file_path] and [filename] in the database.
  ///
  /// Called by [FolderWatchService] when a PDF is renamed or moved on disk.
  Future<void> updateFilePath(
      String id, String newPath, String newFilename) async {
    await (_db.update(_db.scores)..where((s) => s.id.equals(id)))
        .write(ScoresCompanion(
      localFilePath: Value(newPath),
      filename: Value(newFilename),
      updatedAt: Value(_clock.now()),
    ));
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.scores)..where((s) => s.id.equals(id))).go();
      // Also clean up FTS index entry (triggers handle new installs)
      await _db.customStatement(
        'DELETE FROM score_search WHERE id = ?',
        [id],
      );
    });
  }

  // ─── Tag management ───────────────────────────────────────────────────────

  Future<void> setTags(String scoreId, List<String> tags) async {
    await _db.transaction(() async {
      await (_db.delete(_db.scoreTags)..where((t) => t.scoreId.equals(scoreId)))
          .go();

      final normalised = tags.map((t) => t.trim().toLowerCase()).toSet();
      for (final tag in normalised) {
        await _db.into(_db.scoreTags).insert(
              ScoreTagsCompanion.insert(scoreId: scoreId, tag: tag),
            );
      }

      final score = await getById(scoreId);
      if (score != null) {
        await _db.rebuildScoreSearch(
          scoreId,
          score.title,
          normalised.join(' '),
        );
      }

      await (_db.update(_db.scores)..where((s) => s.id.equals(scoreId)))
          .write(ScoresCompanion(updatedAt: Value(_clock.now())));
    });
  }

  Future<List<String>> getTags(String scoreId) async {
    final rows = await (_db.select(_db.scoreTags)
          ..where((t) => t.scoreId.equals(scoreId)))
        .get();
    return rows.map((r) => r.tag).toList();
  }

  // ─── Mapping ──────────────────────────────────────────────────────────────

  ScoreModel _mapRow(Score row) => ScoreModel(
        id: row.id,
        title: row.title,
        filename: row.filename,
        localFilePath: row.localFilePath,
        totalPages: row.totalPages,
        thumbnailPath: row.thumbnailPath,
        updatedAt: row.updatedAt,
      );

  /// Maps a raw SQL QueryRow (from customSelect) to [ScoreModel].
  /// Dates are stored as Unix milliseconds (Drift default).
  ScoreModel _mapSqlRow(QueryRow row) {
    final tagsFlat = row.readNullable<String>('tags_flat');
    final tags = (tagsFlat == null || tagsFlat.isEmpty)
        ? <String>[]
        : tagsFlat.split('|')
      ..sort();
    return ScoreModel(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      filename: row.read<String>('filename'),
      localFilePath: row.read<String>('local_file_path'),
      totalPages: row.read<int>('total_pages'),
      thumbnailPath: row.readNullable<String>('thumbnail_path'),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
      effectiveTags: tags,
    );
  }
}

/// Riverpod provider for [ScoreRepository].
final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  final clock = ref.watch(clockServiceProvider);
  return ScoreRepository(db, clock);
});
