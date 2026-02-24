import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';

void main() {
  final now = DateTime(2024, 3, 10, 9, 0);

  FolderModel makeFolder({
    String id = 'folder-1',
    String name = 'Classical',
    String? parentFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FolderModel(
        id: id,
        name: name,
        parentFolderId: parentFolderId,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
      );

  group('FolderModel', () {
    test('constructs with required fields', () {
      final folder = makeFolder();
      expect(folder.id, 'folder-1');
      expect(folder.name, 'Classical');
      expect(folder.parentFolderId, isNull);
    });

    test('constructs with optional parentFolderId', () {
      final folder = makeFolder(parentFolderId: 'parent-1');
      expect(folder.parentFolderId, 'parent-1');
    });

    group('copyWith', () {
      test('returns identical object when no args', () {
        final folder = makeFolder();
        final copy = folder.copyWith();
        expect(copy.id, folder.id);
        expect(copy.name, folder.name);
        expect(copy.parentFolderId, folder.parentFolderId);
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
