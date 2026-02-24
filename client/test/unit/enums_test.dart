import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';

void main() {
  group('SyncState', () {
    test('has expected values', () {
      expect(SyncState.values.length, 5);
      expect(SyncState.synced.name, 'synced');
      expect(SyncState.pendingUpload.name, 'pendingUpload');
      expect(SyncState.pendingUpdate.name, 'pendingUpdate');
      expect(SyncState.pendingDelete.name, 'pendingDelete');
      expect(SyncState.conflict.name, 'conflict');
    });
  });

  group('AnnotationTool', () {
    test('has expected values', () {
      expect(AnnotationTool.values.length, 3);
      expect(AnnotationTool.pen.name, 'pen');
      expect(AnnotationTool.highlighter.name, 'highlighter');
      expect(AnnotationTool.eraser.name, 'eraser');
    });
  });

  group('SyncOperationType', () {
    test('has expected values', () {
      expect(SyncOperationType.values.length, 3);
      expect(SyncOperationType.create.name, 'create');
      expect(SyncOperationType.update.name, 'update');
      expect(SyncOperationType.delete.name, 'delete');
    });
  });

  group('SyncEntityType', () {
    test('has expected values', () {
      expect(SyncEntityType.values.length, 5);
      expect(SyncEntityType.score.name, 'score');
      expect(SyncEntityType.folder.name, 'folder');
      expect(SyncEntityType.setList.name, 'setList');
      expect(SyncEntityType.setListEntry.name, 'setListEntry');
      expect(SyncEntityType.annotationLayer.name, 'annotationLayer');
    });
  });
}
