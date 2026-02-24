import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';

void main() {
  group('SyncState', () {
    test('has expected values', () {
      expect(SyncState.values, hasLength(5));
      expect(SyncState.values, contains(SyncState.synced));
      expect(SyncState.values, contains(SyncState.pendingUpload));
      expect(SyncState.values, contains(SyncState.pendingUpdate));
      expect(SyncState.values, contains(SyncState.pendingDelete));
      expect(SyncState.values, contains(SyncState.conflict));
    });

    test('synced name', () {
      expect(SyncState.synced.name, 'synced');
    });

    test('pendingUpload name', () {
      expect(SyncState.pendingUpload.name, 'pendingUpload');
    });

    test('pendingUpdate name', () {
      expect(SyncState.pendingUpdate.name, 'pendingUpdate');
    });

    test('pendingDelete name', () {
      expect(SyncState.pendingDelete.name, 'pendingDelete');
    });

    test('conflict name', () {
      expect(SyncState.conflict.name, 'conflict');
    });
  });

  group('AnnotationTool', () {
    test('has expected values', () {
      expect(AnnotationTool.values, hasLength(3));
      expect(AnnotationTool.values, contains(AnnotationTool.pen));
      expect(AnnotationTool.values, contains(AnnotationTool.highlighter));
      expect(AnnotationTool.values, contains(AnnotationTool.eraser));
    });
  });

  group('SyncOperationType', () {
    test('has expected values', () {
      expect(SyncOperationType.values, hasLength(3));
      expect(SyncOperationType.values, contains(SyncOperationType.create));
      expect(SyncOperationType.values, contains(SyncOperationType.update));
      expect(SyncOperationType.values, contains(SyncOperationType.delete));
    });
  });

  group('SyncEntityType', () {
    test('has expected values', () {
      expect(SyncEntityType.values, hasLength(5));
      expect(SyncEntityType.values, contains(SyncEntityType.score));
      expect(SyncEntityType.values, contains(SyncEntityType.folder));
      expect(SyncEntityType.values, contains(SyncEntityType.setList));
      expect(SyncEntityType.values, contains(SyncEntityType.setListEntry));
      expect(
        SyncEntityType.values,
        contains(SyncEntityType.annotationLayer),
      );
    });
  });
}
