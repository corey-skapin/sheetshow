import 'package:sheetshow/core/models/enums.dart';

// T076: SyncQueueEntry — maps to sync_queue Drift table.

/// A queued sync operation waiting to be pushed to the server.
class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payloadJson,
    required this.status,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.errorMessage,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operation;
  final String? payloadJson;
  final String status;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final String? errorMessage;

  SyncQueueEntry copyWith({
    String? status,
    int? attemptCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) =>
      SyncQueueEntry(
        id: id,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payloadJson: payloadJson,
        status: status ?? this.status,
        createdAt: createdAt,
        attemptCount: attemptCount ?? this.attemptCount,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
