import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/sync/models/sync_queue_entry.dart';

void main() {
  final createdAt = DateTime(2024, 9, 1, 8, 0);
  final lastAttempt = DateTime(2024, 9, 1, 9, 0);

  SyncQueueEntry makeEntry({
    String id = 'entry-1',
    SyncEntityType entityType = SyncEntityType.score,
    String entityId = 'score-1',
    SyncOperationType operation = SyncOperationType.create,
    String? payloadJson,
    String status = 'pending',
    DateTime? createdAt,
    int attemptCount = 0,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) =>
      SyncQueueEntry(
        id: id,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payloadJson: payloadJson,
        status: status,
        createdAt: createdAt ?? DateTime(2024, 9, 1, 8, 0),
        attemptCount: attemptCount,
        lastAttemptAt: lastAttemptAt,
        errorMessage: errorMessage,
      );

  group('SyncQueueEntry', () {
    test('constructs with required fields', () {
      final entry = makeEntry();
      expect(entry.id, 'entry-1');
      expect(entry.entityType, SyncEntityType.score);
      expect(entry.entityId, 'score-1');
      expect(entry.operation, SyncOperationType.create);
      expect(entry.status, 'pending');
      expect(entry.attemptCount, 0);
      expect(entry.payloadJson, isNull);
      expect(entry.lastAttemptAt, isNull);
      expect(entry.errorMessage, isNull);
    });

    test('constructs with optional fields', () {
      final entry = makeEntry(
        payloadJson: '{"title":"Bach"}',
        attemptCount: 2,
        lastAttemptAt: lastAttempt,
        errorMessage: 'timeout',
      );
      expect(entry.payloadJson, '{"title":"Bach"}');
      expect(entry.attemptCount, 2);
      expect(entry.lastAttemptAt, lastAttempt);
      expect(entry.errorMessage, 'timeout');
    });

    group('copyWith', () {
      test('returns same values when no args provided', () {
        final entry = makeEntry();
        final copy = entry.copyWith();
        expect(copy.id, entry.id);
        expect(copy.entityType, entry.entityType);
        expect(copy.entityId, entry.entityId);
        expect(copy.status, entry.status);
        expect(copy.attemptCount, entry.attemptCount);
      });

      test('copies with new status', () {
        final entry = makeEntry();
        final copy = entry.copyWith(status: 'failed');
        expect(copy.status, 'failed');
        expect(copy.id, entry.id);
      });

      test('copies with new attemptCount', () {
        final entry = makeEntry();
        final copy = entry.copyWith(attemptCount: 3);
        expect(copy.attemptCount, 3);
      });

      test('copies with new lastAttemptAt', () {
        final entry = makeEntry();
        final copy = entry.copyWith(lastAttemptAt: lastAttempt);
        expect(copy.lastAttemptAt, lastAttempt);
      });

      test('copies with new errorMessage', () {
        final entry = makeEntry();
        final copy = entry.copyWith(errorMessage: 'network error');
        expect(copy.errorMessage, 'network error');
      });

      test('preserves immutable fields', () {
        final entry = makeEntry(
          entityType: SyncEntityType.folder,
          operation: SyncOperationType.delete,
          payloadJson: '{}',
          createdAt: createdAt,
        );
        final copy = entry.copyWith(status: 'done');
        expect(copy.entityType, SyncEntityType.folder);
        expect(copy.operation, SyncOperationType.delete);
        expect(copy.payloadJson, '{}');
        expect(copy.createdAt, createdAt);
      });
    });
  });
}
