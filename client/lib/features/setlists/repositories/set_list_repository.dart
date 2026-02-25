import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';
import 'package:sheetshow/features/setlists/models/set_list_model.dart';

/// Client-side set list repository with ordered entry management.
class SetListRepository {
  SetListRepository(this._db);

  final AppDatabase _db;

  // ─── Watch ────────────────────────────────────────────────────────────────

  Stream<List<SetListModel>> watchAll() {
    return (_db.select(_db.setLists)
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
          ),
        );
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.setLists)..where((sl) => sl.id.equals(id)))
        .write(SetListsCompanion(
      name: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.setLists)..where((sl) => sl.id.equals(id))).go();
  }

  Future<void> addEntry(String setListId, String scoreId) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      // Compute next orderIndex in-DB to avoid a round-trip SELECT.
      await _db.customStatement(
        'INSERT INTO set_list_entries (id, set_list_id, score_id, order_index, added_at) '
        'VALUES (?, ?, ?, COALESCE((SELECT MAX(order_index) + 1 FROM set_list_entries WHERE set_list_id = ?), 0), ?)',
        [id, setListId, scoreId, setListId, now.millisecondsSinceEpoch],
      );
      await _touchSetList(setListId);
    });
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
      // Phase 1: shift all indices to a high range to clear UNIQUE constraint
      // conflicts that would otherwise occur during in-place updates.
      for (var i = 0; i < orderedEntryIds.length; i++) {
        await (_db.update(_db.setListEntries)
              ..where((e) => e.id.equals(orderedEntryIds[i])))
            .write(SetListEntriesCompanion(
          orderIndex: Value(i + 100000),
        ));
      }
      // Phase 2: apply the correct final indices.
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
        .write(SetListsCompanion(updatedAt: Value(DateTime.now())));
  }
}

/// Riverpod provider for [SetListRepository].
final setListRepositoryProvider = Provider<SetListRepository>((ref) {
  return SetListRepository(ref.watch(databaseProvider));
});
