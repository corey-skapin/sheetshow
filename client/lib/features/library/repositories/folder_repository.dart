import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/constants/app_constants.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/error_display_service.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';

/// Client-side folder repository with depth enforcement.
class FolderRepository {
  FolderRepository(this._db, this._clock);

  final AppDatabase _db;
  final ClockService _clock;

  /// Reactive stream of all folders.
  Stream<List<FolderModel>> watchAll() {
    final query = _db.select(_db.folders)
      ..orderBy([(f) => OrderingTerm.asc(f.name)]);
    return query.watch().map((rows) => rows.map(_mapRow).toList());
  }

  Future<FolderModel?> getById(String id) async {
    final row = await (_db.select(_db.folders)..where((f) => f.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  /// Returns the folder whose [FolderModel.diskPath] matches [diskPath].
  ///
  /// Paths are normalized before comparison so `/` vs `\` and trailing-slash
  /// differences do not cause mismatches.
  Future<FolderModel?> getByDiskPath(String diskPath) async {
    final normalised = path.normalize(diskPath);
    final row = await (_db.select(_db.folders)
          ..where((f) => f.folderPath.equals(normalised)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<void> create(FolderModel folder) async {
    if (folder.parentFolderId != null) {
      final depth = await getDepth(folder.parentFolderId!);
      if (depth >= kMaxFolderDepth) throw const FolderDepthException();
    } else {
      // Root-level folders must have unique names.
      final dup = await (_db.select(_db.folders)
            ..where(
                (f) => f.name.equals(folder.name) & f.parentFolderId.isNull()))
          .getSingleOrNull();
      if (dup != null) throw DuplicateFolderNameException(folder.name);
    }
    await _db.into(_db.folders).insert(
          FoldersCompanion.insert(
            id: folder.id,
            name: folder.name,
            parentFolderId: Value(folder.parentFolderId),
            createdAt: folder.createdAt,
            updatedAt: folder.updatedAt,
            folderPath: Value(folder.diskPath != null
                ? path.normalize(folder.diskPath!)
                : null),
          ),
        );
  }

  /// Renames the folder in the database.
  ///
  /// If [FolderModel.diskPath] is set and the directory exists on disk, it is
  /// also renamed and [folder_path] is updated in the database.
  Future<void> rename(String id, String name) async {
    final folder = await getById(id);

    if (folder?.diskPath != null) {
      final oldDir = Directory(folder!.diskPath!);
      if (await oldDir.exists()) {
        final parentPath = path.dirname(folder.diskPath!);
        final newDiskPath = path.join(parentPath, name);
        await oldDir.rename(newDiskPath);
        try {
          await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
              .write(FoldersCompanion(
            name: Value(name),
            folderPath: Value(newDiskPath),
            updatedAt: Value(_clock.now()),
          ));
        } catch (e) {
          // Rollback the directory rename so filesystem stays consistent.
          await Directory(newDiskPath).rename(folder.diskPath!);
          rethrow;
        }
        return;
      }
    }

    await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(
      name: Value(name),
      updatedAt: Value(_clock.now()),
    ));
  }

  Future<void> reparent(String id, String? parentId) async {
    if (parentId != null) {
      final depth = await getDepth(parentId);
      if (depth >= kMaxFolderDepth) throw const FolderDepthException();
    }
    await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(
      parentFolderId: Value(parentId),
      updatedAt: Value(_clock.now()),
    ));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
  }

  /// Updates [folder_path] and [name] in the database when the directory is
  /// moved externally (called by [FolderWatchService]).
  Future<void> updateDiskPath(
      String id, String newName, String newDiskPath) async {
    await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(
      name: Value(newName),
      folderPath: Value(path.normalize(newDiskPath)),
      updatedAt: Value(_clock.now()),
    ));
  }

  // ─── Folder tags ───────────────────────────────────────────────────────────

  Future<List<String>> getTags(String folderId) async {
    final rows = await (_db.select(_db.folderTags)
          ..where((t) => t.folderId.equals(folderId)))
        .get();
    return rows.map((r) => r.tag).toList();
  }

  Stream<List<String>> watchTags(String folderId) {
    return (_db.select(_db.folderTags)
          ..where((t) => t.folderId.equals(folderId)))
        .watch()
        .map((rows) => rows.map((r) => r.tag).toList());
  }

  Future<void> setTags(String folderId, List<String> tags) async {
    final normalised = tags.map((t) => t.trim().toLowerCase()).toSet();
    await _db.transaction(() async {
      await (_db.delete(_db.folderTags)
            ..where((t) => t.folderId.equals(folderId)))
          .go();
      for (final tag in normalised) {
        await _db.into(_db.folderTags).insert(
              FolderTagsCompanion.insert(folderId: folderId, tag: tag),
            );
      }
    });
    // Rebuild FTS for all scores in this folder so searches include folder tags.
    await _rebuildFtsForFolder(folderId, normalised.toList());
  }

  Future<void> _rebuildFtsForFolder(
      String folderId, List<String> folderTags) async {
    final memberships = await (_db.select(_db.scoreFolderMemberships)
          ..where((m) => m.folderId.equals(folderId)))
        .get();
    for (final m in memberships) {
      final score = await (_db.select(_db.scores)
            ..where((s) => s.id.equals(m.scoreId)))
          .getSingleOrNull();
      if (score == null) continue;
      final ownTagRows = await (_db.select(_db.scoreTags)
            ..where((t) => t.scoreId.equals(m.scoreId)))
          .get();
      final allTags = {
        ...ownTagRows.map((r) => r.tag),
        ...folderTags,
      };
      await _db.rebuildScoreSearch(score.id, score.title, allTags.join(' '));
    }
  }

  /// Walk the parent chain to determine nesting depth (0 = root).
  Future<int> getDepth(String id) async {
    var depth = 0;
    var current = id;
    while (true) {
      final row = await (_db.select(_db.folders)
            ..where((f) => f.id.equals(current)))
          .getSingleOrNull();
      if (row == null || row.parentFolderId == null) break;
      current = row.parentFolderId!;
      depth++;
      if (depth >= kMaxFolderDepth) break;
    }
    return depth;
  }

  FolderModel _mapRow(Folder row) => FolderModel(
        id: row.id,
        name: row.name,
        parentFolderId: row.parentFolderId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        diskPath: row.folderPath,
      );
}

/// Riverpod provider for [FolderRepository].
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(
    ref.watch(databaseProvider).requireValue,
    ref.watch(clockServiceProvider),
  );
});
