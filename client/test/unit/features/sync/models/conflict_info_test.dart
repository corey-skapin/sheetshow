import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/sync/models/conflict_info.dart';

void main() {
  group('ConflictType', () {
    test('has expected values', () {
      expect(ConflictType.values, hasLength(4));
      expect(ConflictType.values, contains(ConflictType.metadataModified));
      expect(ConflictType.values, contains(ConflictType.annotationModified));
      expect(ConflictType.values, contains(ConflictType.deleteVsUpdate));
      expect(ConflictType.values, contains(ConflictType.setListModified));
    });
  });

  group('ConflictInfo', () {
    test('constructs with required fields', () {
      const info = ConflictInfo(
        entityType: SyncEntityType.score,
        entityId: 'score-1',
        conflictType: ConflictType.metadataModified,
        localPayload: '{"title":"local"}',
        serverPayload: '{"title":"server"}',
        serverVersion: 3,
      );
      expect(info.entityType, SyncEntityType.score);
      expect(info.entityId, 'score-1');
      expect(info.conflictType, ConflictType.metadataModified);
      expect(info.localPayload, '{"title":"local"}');
      expect(info.serverPayload, '{"title":"server"}');
      expect(info.serverVersion, 3);
    });

    test('constructs for annotation conflict', () {
      const info = ConflictInfo(
        entityType: SyncEntityType.annotationLayer,
        entityId: 'layer-1',
        conflictType: ConflictType.annotationModified,
        localPayload: '[]',
        serverPayload: '[{"id":"s1"}]',
        serverVersion: 2,
      );
      expect(info.conflictType, ConflictType.annotationModified);
    });

    test('constructs for delete vs update conflict', () {
      const info = ConflictInfo(
        entityType: SyncEntityType.folder,
        entityId: 'folder-1',
        conflictType: ConflictType.deleteVsUpdate,
        localPayload: '',
        serverPayload: '{"name":"updated"}',
        serverVersion: 5,
      );
      expect(info.conflictType, ConflictType.deleteVsUpdate);
    });

    test('constructs for setList conflict', () {
      const info = ConflictInfo(
        entityType: SyncEntityType.setList,
        entityId: 'setlist-1',
        conflictType: ConflictType.setListModified,
        localPayload: '{"name":"mine"}',
        serverPayload: '{"name":"theirs"}',
        serverVersion: 1,
      );
      expect(info.conflictType, ConflictType.setListModified);
    });
  });
}
