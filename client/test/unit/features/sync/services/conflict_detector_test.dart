import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/sync/models/conflict_info.dart';
import 'package:sheetshow/features/sync/models/sync_queue_entry.dart';
import 'package:sheetshow/features/sync/services/conflict_detector.dart';

SyncQueueEntry _entry({
  required SyncEntityType entityType,
  required SyncOperationType operation,
  String entityId = 'e-1',
  String? payload,
}) =>
    SyncQueueEntry(
      id: 'q-1',
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: payload,
      status: 'pending',
      createdAt: DateTime(2025),
    );

void main() {
  late ConflictDetector detector;

  setUp(() => detector = ConflictDetector());

  group('ConflictDetector.processResults', () {
    test('given_noConflicts_when_processed_then_returnsEmpty', () {
      final ops = [_entry(entityType: SyncEntityType.score, operation: SyncOperationType.update)];
      final results = [
        {'status': 'accepted'}
      ];
      expect(detector.processResults(ops, results), isEmpty);
    });

    test('given_conflictResult_when_processed_then_returnsConflictInfo', () {
      final ops = [
        _entry(
          entityType: SyncEntityType.score,
          entityId: 'score-1',
          operation: SyncOperationType.update,
          payload: '{"title":"local"}',
        )
      ];
      final results = [
        {
          'status': 'conflict',
          'serverPayload': '{"title":"server"}',
          'serverVersion': 3,
        }
      ];
      final conflicts = detector.processResults(ops, results);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.entityId, 'score-1');
      expect(conflicts.first.conflictType, ConflictType.metadataModified);
      expect(conflicts.first.localPayload, '{"title":"local"}');
      expect(conflicts.first.serverPayload, '{"title":"server"}');
      expect(conflicts.first.serverVersion, 3);
    });

    test('given_multipleResults_when_oneConflict_then_returnsSingleConflict', () {
      final ops = [
        _entry(entityType: SyncEntityType.score, operation: SyncOperationType.create),
        _entry(entityType: SyncEntityType.score, operation: SyncOperationType.update, entityId: 'e-2'),
        _entry(entityType: SyncEntityType.score, operation: SyncOperationType.update, entityId: 'e-3'),
      ];
      final results = [
        {'status': 'accepted'},
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1},
        {'status': 'accepted'},
      ];
      final conflicts = detector.processResults(ops, results);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.entityId, 'e-2');
    });

    test('given_resultsLongerThanOps_when_processed_then_clampsToOpsLength', () {
      final ops = [_entry(entityType: SyncEntityType.score, operation: SyncOperationType.update)];
      final results = [
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1},
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 2},
      ];
      expect(detector.processResults(ops, results), hasLength(1));
    });

    test('given_conflictWithNullPayloads_when_processed_then_usesDefaults', () {
      final ops = [_entry(entityType: SyncEntityType.score, operation: SyncOperationType.update)];
      final results = [
        {'status': 'conflict'}
      ];
      final conflicts = detector.processResults(ops, results);
      expect(conflicts.first.localPayload, '{}');
      expect(conflicts.first.serverPayload, '{}');
      expect(conflicts.first.serverVersion, 0);
    });

    test('given_emptyInputs_when_processed_then_returnsEmpty', () {
      expect(detector.processResults([], []), isEmpty);
    });
  });

  group('ConflictDetector._inferConflictType', () {
    test('given_deleteOperation_when_processed_then_deleteVsUpdate', () {
      final ops = [_entry(entityType: SyncEntityType.score, operation: SyncOperationType.delete)];
      final results = [
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1}
      ];
      expect(detector.processResults(ops, results).first.conflictType, ConflictType.deleteVsUpdate);
    });

    test('given_annotationLayer_when_updateConflict_then_annotationModified', () {
      final ops = [_entry(entityType: SyncEntityType.annotationLayer, operation: SyncOperationType.update)];
      final results = [
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1}
      ];
      expect(detector.processResults(ops, results).first.conflictType, ConflictType.annotationModified);
    });

    test('given_setList_when_updateConflict_then_setListModified', () {
      final ops = [_entry(entityType: SyncEntityType.setList, operation: SyncOperationType.update)];
      final results = [
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1}
      ];
      expect(detector.processResults(ops, results).first.conflictType, ConflictType.setListModified);
    });

    test('given_setListEntry_when_updateConflict_then_setListModified', () {
      final ops = [_entry(entityType: SyncEntityType.setListEntry, operation: SyncOperationType.update)];
      final results = [
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1}
      ];
      expect(detector.processResults(ops, results).first.conflictType, ConflictType.setListModified);
    });

    test('given_folder_when_updateConflict_then_metadataModified', () {
      final ops = [_entry(entityType: SyncEntityType.folder, operation: SyncOperationType.update)];
      final results = [
        {'status': 'conflict', 'serverPayload': '{}', 'serverVersion': 1}
      ];
      expect(detector.processResults(ops, results).first.conflictType, ConflictType.metadataModified);
    });
  });
}
