import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';

void main() {
  final now = DateTime(2024, 3, 10, 9, 0);

  FolderModel makeFolder({
    String id = 'folder-1',
    String name = 'Classical',
    String? parentFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState syncState = SyncState.synced,
    String? cloudId,
    bool isDeleted = false,
  }) =>
      FolderModel(
        id: id,
        name: name,
        parentFolderId: parentFolderId,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
        syncState: syncState,
        cloudId: cloudId,
        isDeleted: isDeleted,
      );

  group('FolderModel', () {
    test('constructs with required fields', () {
      final folder = makeFolder();
      expect(folder.id, 'folder-1');
      expect(folder.name, 'Classical');
      expect(folder.syncState, SyncState.synced);
      expect(folder.isDeleted, false);
      expect(folder.parentFolderId, isNull);
      expect(folder.cloudId, isNull);
    });

    test('constructs with optional fields', () {
      final folder = makeFolder(
        parentFolderId: 'parent-1',
        cloudId: 'cloud-abc',
        isDeleted: true,
      );
      expect(folder.parentFolderId, 'parent-1');
      expect(folder.cloudId, 'cloud-abc');
      expect(folder.isDeleted, true);
    });

    group('copyWith', () {
      test('returns identical object when no args', () {
        final folder = makeFolder();
        final copy = folder.copyWith();
        expect(copy.id, folder.id);
        expect(copy.name, folder.name);
        expect(copy.syncState, folder.syncState);
        expect(copy.isDeleted, folder.isDeleted);
      });

      test('copies with new name', () {
        final folder = makeFolder();
        final copy = folder.copyWith(name: 'Romantic');
        expect(copy.name, 'Romantic');
        expect(copy.id, folder.id);
      });

      test('copies with parentFolderId', () {
        final folder = makeFolder();
        final copy = folder.copyWith(parentFolderId: 'parent-2');
        expect(copy.parentFolderId, 'parent-2');
      });

      test('copies with syncState', () {
        final folder = makeFolder();
        final copy = folder.copyWith(syncState: SyncState.pendingUpdate);
        expect(copy.syncState, SyncState.pendingUpdate);
      });

      test('copies with cloudId', () {
        final folder = makeFolder();
        final copy = folder.copyWith(cloudId: 'cloud-123');
        expect(copy.cloudId, 'cloud-123');
      });

      test('copies with isDeleted', () {
        final folder = makeFolder();
        final copy = folder.copyWith(isDeleted: true);
        expect(copy.isDeleted, true);
      });
    });

    group('toJson', () {
      test('serializes required fields', () {
        final folder = makeFolder(
          id: 'folder-1',
          name: 'Classical',
          updatedAt: now,
        );
        final json = folder.toJson();
        expect(json['id'], 'folder-1');
        expect(json['name'], 'Classical');
        expect(json['updatedAt'], now.toIso8601String());
        expect(json['parentFolderId'], isNull);
        expect(json['cloudId'], isNull);
      });

      test('serializes optional fields', () {
        final folder = makeFolder(
          parentFolderId: 'parent-1',
          cloudId: 'cloud-1',
        );
        final json = folder.toJson();
        expect(json['parentFolderId'], 'parent-1');
        expect(json['cloudId'], 'cloud-1');
      });
    });

    group('fromJson', () {
      test('deserializes from JSON', () {
        final json = {
          'id': 'folder-2',
          'name': 'Baroque',
          'parentFolderId': 'parent-1',
          'cloudId': 'cloud-folder-2',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
        final folder = FolderModel.fromJson(json);
        expect(folder.id, 'folder-2');
        expect(folder.name, 'Baroque');
        expect(folder.parentFolderId, 'parent-1');
        expect(folder.syncState, SyncState.synced);
        expect(folder.cloudId, 'cloud-folder-2');
      });

      test('handles missing optional fields', () {
        const json = <String, dynamic>{
          'id': 'folder-3',
          'name': 'Jazz',
        };
        final folder = FolderModel.fromJson(json);
        expect(folder.id, 'folder-3');
        expect(folder.name, 'Jazz');
        expect(folder.parentFolderId, isNull);
      });

      test('handles invalid date strings gracefully', () {
        const json = <String, dynamic>{
          'id': 'folder-4',
          'name': 'Rock',
          'createdAt': '',
          'updatedAt': 'bad-date',
        };
        expect(() => FolderModel.fromJson(json), returnsNormally);
      });
    });

    group('equality', () {
      test('equal when same id', () {
        final a = makeFolder(id: 'folder-1');
        final b = makeFolder(id: 'folder-1', name: 'Different Name');
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        final a = makeFolder(id: 'folder-1');
        final b = makeFolder(id: 'folder-2');
        expect(a, isNot(equals(b)));
      });

      test('identical object equals itself', () {
        final a = makeFolder();
        expect(a, equals(a));
      });

      test('hashCode based on id', () {
        final a = makeFolder(id: 'folder-1');
        final b = makeFolder(id: 'folder-1');
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
