import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/features/library/models/score_model.dart';

/// Client-side score repository backed by Drift/SQLite.
class ScoreRepository {
  ScoreRepository(this._db);

  final AppDatabase _db;

  // ─── Watch ────────────────────────────────────────────────────────────────

  /// Reactive stream of all scores.
  /// When [folderId] is set, returns only scores that have a membership in that folder.
  Stream<List<ScoreModel>> watchAll({String? folderId}) {
    if (folderId == null) {
      final query = _db.select(_db.scores)
        ..orderBy([(s) => OrderingTerm.asc(s.title)]);
      return query.watch().map((rows) => rows.map(_mapRow).toList());
    }
    final query = _db.select(_db.scores).join([
      innerJoin(
        _db.scoreFolderMemberships,
        _db.scoreFolderMemberships.scoreId.equalsExp(_db.scores.id),
      ),
    ])
      ..where(_db.scoreFolderMemberships.folderId.equals(folderId))
      ..orderBy([OrderingTerm.asc(_db.scores.title)]);
    return query.watch().map(
          (rows) => rows.map((r) => _mapRow(r.readTable(_db.scores))).toList(),
        );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  Future<ScoreModel?> getById(String id) async {
    final row = await (_db.select(_db.scores)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  Future<void> insert(ScoreModel score) async {
    await _db.into(_db.scores).insert(
          ScoresCompanion.insert(
            id: score.id,
            title: score.title,
            filename: score.filename,
            localFilePath: score.localFilePath,
            totalPages: score.totalPages,
            thumbnailPath: Value(score.thumbnailPath),
            folderId: Value(score.folderId),
            importedAt: score.importedAt,
            updatedAt: score.updatedAt,
          ),
        );
    if (score.folderId != null) {
      await _addMembership(score.id, score.folderId!);
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

  Future<void> update(ScoreModel score) async {
    await (_db.update(_db.scores)..where((s) => s.id.equals(score.id)))
        .write(ScoresCompanion(
      title: Value(score.title),
      folderId: Value(score.folderId),
      thumbnailPath: Value(score.thumbnailPath),
      updatedAt: Value(DateTime.now()),
    ));
    await _db.rebuildScoreSearch(score.id, score.title, '');
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
          .write(ScoresCompanion(updatedAt: Value(DateTime.now())));
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
        folderId: row.folderId,
        importedAt: row.importedAt,
        updatedAt: row.updatedAt,
      );
}

/// Riverpod provider for [ScoreRepository].
final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ScoreRepository(db);
});
