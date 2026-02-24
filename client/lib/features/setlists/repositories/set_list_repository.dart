import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';
import 'package:sheetshow/features/setlists/models/set_list_model.dart';

// T059: SetListRepository — Drift DAO for set list management.

/// Client-side set list repository with ordered entry management.
class SetListRepository {
  SetListRepository(this._db);

  final AppDatabase _db;

  // ─── Watch ────────────────────────────────────────────────────────────────

  Stream<List<SetListModel>> watchAll() {
    return (_db.select(_db.setLists)
          ..where((sl) => sl.isDeleted.equals(false))
          ..orderBy([(sl) => OrderingTerm.desc(sl.updatedAt)]))
        .watch()
        .asyncMap((rows) async {
      return Future.wait(rows.map(_loadWithEntries));
    });
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  Future<SetListModel?> getWithEntries(String id) async {
    final row = await (_db.select(_db.setLists)
          ..where((sl) => sl.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _loadWithEntries(row);
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  Future<void> create(SetListModel setList) async {
    await _db.into(_db.setLists).insert(
          SetListsCompanion.insert(
            id: setList.id,
            name: setList.name,
            createdAt: setList.createdAt,
            updatedAt: setList.updatedAt,
            syncState: Value(setList.syncState),
            cloudId: Value(setList.cloudId),
            serverVersion: Value(setList.serverVersion),
            isDeleted: Value(setList.isDeleted),
          ),
        );
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.setLists)..where((sl) => sl.id.equals(id)))
        .write(SetListsCompanion(
      name: Value(name),
      updatedAt: Value(DateTime.now()),
      syncState: const Value(SyncState.pendingUpdate),
    ));
  }

  Future<void> softDelete(String id) async {
    await (_db.update(_db.setLists)..where((sl) => sl.id.equals(id)))
        .write(SetListsCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now()),
      syncState: const Value(SyncState.pendingDelete),
    ));
  }

  Future<void> addEntry(String setListId, String scoreId) async {
    // Get next order index
    final entries = await (_db.select(_db.setListEntries)
          ..where((e) => e.setListId.equals(setListId))
          ..orderBy([(e) => OrderingTerm.desc(e.orderIndex)]))
        .get();
    final nextIndex = entries.isEmpty ? 0 : entries.first.orderIndex + 1;

    await _db.into(_db.setListEntries).insert(
          SetListEntriesCompanion.insert(
            id: const Uuid().v4(),
            setListId: setListId,
            scoreId: scoreId,
            orderIndex: nextIndex,
            addedAt: DateTime.now(),
          ),
        );

    await _touchSetList(setListId);
  }

  Future<void> removeEntry(String entryId) async {
    final entry = await (_db.select(_db.setListEntries)
          ..where((e) => e.id.equals(entryId)))
        .getSingleOrNull();
    await (_db.delete(_db.setListEntries)..where((e) => e.id.equals(entryId)))
        .go();
    if (entry != null) await _touchSetList(entry.setListId);
  }

  /// Reorder all entries by providing the complete ordered list of entry IDs.
  Future<void> reorderEntries(
    String setListId,
    List<String> orderedEntryIds,
  ) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedEntryIds.length; i++) {
        await (_db.update(_db.setListEntries)
              ..where((e) => e.id.equals(orderedEntryIds[i])))
            .write(SetListEntriesCompanion(
          orderIndex: Value(i),
        ));
      }
      await _touchSetList(setListId);
    });
  }

  Future<void> updateSyncState(String id, SyncState state) async {
    await (_db.update(_db.setLists)..where((sl) => sl.id.equals(id)))
        .write(SetListsCompanion(syncState: Value(state)));
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<SetListModel> _loadWithEntries(SetList row) async {
    final entryRows = await (_db.select(_db.setListEntries)
          ..where((e) => e.setListId.equals(row.id))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .get();

    return SetListModel(
      id: row.id,
      name: row.name,
      entries: entryRows.map(_mapEntry).toList(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      syncState: row.syncState,
      cloudId: row.cloudId,
      serverVersion: row.serverVersion,
      isDeleted: row.isDeleted,
    );
  }

  SetListEntryModel _mapEntry(SetListEntry row) => SetListEntryModel(
        id: row.id,
        setListId: row.setListId,
        scoreId: row.scoreId,
        orderIndex: row.orderIndex,
        addedAt: row.addedAt,
      );

  Future<void> _touchSetList(String id) async {
    await (_db.update(_db.setLists)..where((sl) => sl.id.equals(id)))
        .write(SetListsCompanion(
      updatedAt: Value(DateTime.now()),
      syncState: const Value(SyncState.pendingUpdate),
    ));
  }
}

/// Riverpod provider for [SetListRepository].
final setListRepositoryProvider = Provider<SetListRepository>((ref) {
  return SetListRepository(ref.watch(databaseProvider));
});
