import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../models/sync_queue_entry.dart';

// T079: SyncQueueProcessor — reads and deduplicates pending sync queue entries.

/// Reads and deduplicates the sync queue before pushing to the server.
class SyncQueueProcessor {
  SyncQueueProcessor(this._db);

  final AppDatabase _db;

  /// Return a deduplicated, ordered batch of pending operations.
  Future<List<SyncQueueEntry>> getNextBatch() async {
    final rows = await (_db.select(_db.syncQueue)
          ..where((q) => q.status.equals('pending'))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();

    final entries = rows.map(_mapRow).toList();
    return _deduplicate(entries);
  }

  /// Mark entries as in-flight.
  Future<void> markInFlight(List<String> ids) async {
    await (_db.update(_db.syncQueue)
          ..where((q) => q.id.isIn(ids)))
        .write(const SyncQueueCompanion(
      status: Value('in_flight'),
    ));
  }

  /// Mark an entry as synced.
  Future<void> markSynced(String id) async {
    await (_db.delete(_db.syncQueue)..where((q) => q.id.equals(id))).go();
  }

  /// Mark an entry as failed.
  Future<void> markFailed(
    String id,
    String errorMessage,
    int attemptCount,
  ) async {
    final status =
        attemptCount >= kSyncMaxRetries ? 'failed' : 'pending';
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(id)))
        .write(SyncQueueCompanion(
      status: Value(status),
      errorMessage: Value(errorMessage),
      attemptCount: Value(attemptCount),
      lastAttemptAt: Value(DateTime.now()),
    ));
  }

  /// Deduplicate: collapse multiple updates for the same entity.
  List<SyncQueueEntry> _deduplicate(List<SyncQueueEntry> entries) {
    final Map<String, SyncQueueEntry> deduplicated = {};

    for (final entry in entries) {
      final key = '${entry.entityType.name}:${entry.entityId}';
      final existing = deduplicated[key];

      if (existing == null) {
        deduplicated[key] = entry;
      } else if (entry.operation == SyncOperationType.delete) {
        // delete supersedes any pending create/update
        deduplicated[key] = entry;
      } else if (entry.operation == SyncOperationType.update &&
          existing.operation != SyncOperationType.delete) {
        // Keep latest update payload
        deduplicated[key] = entry;
      }
      // else keep existing
    }

    return deduplicated.values.take(kSyncMaxBatchSize).toList();
  }

  SyncQueueEntry _mapRow(SyncQueueData row) => SyncQueueEntry(
        id: row.id,
        entityType: row.entityType,
        entityId: row.entityId,
        operation: row.operation,
        payloadJson: row.payloadJson,
        status: row.status,
        createdAt: row.createdAt,
        attemptCount: row.attemptCount,
        lastAttemptAt: row.lastAttemptAt,
        errorMessage: row.errorMessage,
      );
}

/// Riverpod provider for [SyncQueueProcessor].
final syncQueueProcessorProvider = Provider<SyncQueueProcessor>((ref) {
  return SyncQueueProcessor(ref.watch(databaseProvider));
});
