import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/sync/models/conflict_info.dart';
import 'package:sheetshow/features/sync/models/sync_queue_entry.dart';

// T080: ConflictDetector — processes push response and creates ConflictInfo objects.

/// Processes push response results and generates ConflictInfo for the merge editor.
class ConflictDetector {
  /// Process push operation results and return any conflicts found.
  List<ConflictInfo> processResults(
    List<SyncQueueEntry> operations,
    List<Map<String, dynamic>> results,
  ) {
    final conflicts = <ConflictInfo>[];

    for (var i = 0; i < results.length && i < operations.length; i++) {
      final result = results[i];
      final op = operations[i];

      if (result['status'] == 'conflict') {
        final conflictType = _inferConflictType(op.entityType, op.operation);
        conflicts.add(ConflictInfo(
          entityType: op.entityType,
          entityId: op.entityId,
          conflictType: conflictType,
          localPayload: op.payloadJson ?? '{}',
          serverPayload: result['serverPayload'] as String? ?? '{}',
          serverVersion: result['serverVersion'] as int? ?? 0,
        ));
      }
    }

    return conflicts;
  }

  ConflictType _inferConflictType(
    SyncEntityType entityType,
    SyncOperationType operation,
  ) {
    if (operation == SyncOperationType.delete) {
      return ConflictType.deleteVsUpdate;
    }
    return switch (entityType) {
      SyncEntityType.annotationLayer => ConflictType.annotationModified,
      SyncEntityType.setList ||
      SyncEntityType.setListEntry =>
        ConflictType.setListModified,
      _ => ConflictType.metadataModified,
    };
  }
}

/// Riverpod provider for [ConflictDetector].
final conflictDetectorProvider = Provider<ConflictDetector>(
  (_) => ConflictDetector(),
);
