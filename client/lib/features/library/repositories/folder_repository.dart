import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/constants/app_constants.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/core/services/error_display_service.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';

// T046: FolderRepository — Drift DAO for folder hierarchy management.

/// Client-side folder repository with depth enforcement.
class FolderRepository {
  FolderRepository(this._db);

  final AppDatabase _db;

  /// Reactive stream of all non-deleted folders.
  Stream<List<FolderModel>> watchAll() {
    final query = _db.select(_db.folders)
      ..where((f) => f.isDeleted.equals(false))
      ..orderBy([(f) => OrderingTerm.asc(f.name)]);
    return query.watch().map((rows) => rows.map(_mapRow).toList());
  }

  Future<FolderModel?> getById(String id) async {
    final row = await (_db.select(_db.folders)
          ..where((f) => f.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<void> create(FolderModel folder) async {
    if (folder.parentFolderId != null) {
      final depth = await getDepth(folder.parentFolderId!);
      if (depth >= kMaxFolderDepth) throw const FolderDepthException();
    }
    await _db.into(_db.folders).insert(
          FoldersCompanion.insert(
            id: folder.id,
            name: folder.name,
            parentFolderId: Value(folder.parentFolderId),
            createdAt: folder.createdAt,
            updatedAt: folder.updatedAt,
            syncState: Value(folder.syncState),
            cloudId: Value(folder.cloudId),
            isDeleted: Value(folder.isDeleted),
          ),
        );
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(
      name: Value(name),
      updatedAt: Value(DateTime.now()),
      syncState: Value(SyncState.pendingUpdate),
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
      updatedAt: Value(DateTime.now()),
      syncState: Value(SyncState.pendingUpdate),
    ));
  }

  Future<void> softDelete(String id) async {
    await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now()),
      syncState: Value(SyncState.pendingDelete),
    ));
  }

  Future<void> updateSyncState(String id, SyncState state,
      {String? cloudId}) async {
    await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(FoldersCompanion(
      syncState: Value(state),
      cloudId: cloudId != null ? Value(cloudId) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
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
        syncState: row.syncState,
        cloudId: row.cloudId,
        isDeleted: row.isDeleted,
      );
}

/// Riverpod provider for [FolderRepository].
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(databaseProvider));
});
