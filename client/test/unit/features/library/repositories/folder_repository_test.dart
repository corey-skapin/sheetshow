import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';
import 'package:sheetshow/features/library/repositories/folder_repository.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late FolderRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('folder_repo_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FolderRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FolderModel makeFolder({
    String id = 'f1',
    String name = 'Classical',
    String? diskPath,
  }) =>
      FolderModel(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        diskPath: diskPath,
      );

  // ─── create ─────────────────────────────────────────────────────────────────

  group('create', () {
    test('stores folder_path when diskPath is provided', () async {
      final diskPath = path.join(tempDir.path, 'Classical');
      await repo.create(makeFolder(diskPath: diskPath));

      final folder = await repo.getById('f1');
      expect(folder!.diskPath, diskPath);
    });

    test('stores null folder_path when diskPath is absent', () async {
      await repo.create(makeFolder());

      final folder = await repo.getById('f1');
      expect(folder!.diskPath, isNull);
    });
  });

  // ─── rename ─────────────────────────────────────────────────────────────────

  group('rename', () {
    test('updates name in DB when no diskPath is set', () async {
      await repo.create(makeFolder());

      await repo.rename('f1', 'Romantic');

      final folder = await repo.getById('f1');
      expect(folder!.name, 'Romantic');
    });

    test('updates folder_path in DB when diskPath is set', () async {
      final diskPath = path.join(tempDir.path, 'Classical');
      await Directory(diskPath).create();
      await repo.create(makeFolder(diskPath: diskPath));

      await repo.rename('f1', 'Romantic');

      final folder = await repo.getById('f1');
      expect(folder!.name, 'Romantic');
      expect(folder.diskPath, path.join(tempDir.path, 'Romantic'));
    });

    test('renames directory on disk when diskPath is set', () async {
      final diskPath = path.join(tempDir.path, 'Classical');
      await Directory(diskPath).create();
      await repo.create(makeFolder(diskPath: diskPath));

      await repo.rename('f1', 'Romantic');

      expect(await Directory(diskPath).exists(), isFalse);
      expect(
        await Directory(path.join(tempDir.path, 'Romantic')).exists(),
        isTrue,
      );
    });

    test('only updates DB when disk directory does not exist', () async {
      final diskPath = path.join(tempDir.path, 'NonExistent');
      // Note: we do NOT create the directory
      await repo.create(makeFolder(diskPath: diskPath));

      await repo.rename('f1', 'NewName');

      final folder = await repo.getById('f1');
      expect(folder!.name, 'NewName');
    });
  });

  // ─── getByDiskPath ──────────────────────────────────────────────────────────

  group('getByDiskPath', () {
    test('returns folder with matching diskPath', () async {
      final diskPath = path.join(tempDir.path, 'Jazz');
      await repo.create(makeFolder(diskPath: diskPath));

      final folder = await repo.getByDiskPath(diskPath);
      expect(folder, isNotNull);
      expect(folder!.id, 'f1');
    });

    test('returns null when no folder has that diskPath', () async {
      expect(await repo.getByDiskPath('/no/such/path'), isNull);
    });
  });

  // ─── updateDiskPath ─────────────────────────────────────────────────────────

  group('updateDiskPath', () {
    test('updates both name and folder_path in DB', () async {
      final diskPath = path.join(tempDir.path, 'Old');
      await repo.create(makeFolder(diskPath: diskPath));

      final newDiskPath = path.join(tempDir.path, 'New');
      await repo.updateDiskPath('f1', 'New', newDiskPath);

      final folder = await repo.getById('f1');
      expect(folder!.name, 'New');
      expect(folder.diskPath, newDiskPath);
    });
  });

  // ─── delete ──────────────────────────────────────────────────────────────────

  group('delete', () {
    test('removes folder from database', () async {
      await repo.create(makeFolder());
      await repo.delete('f1');
      expect(await repo.getById('f1'), isNull);
    });

    test('does nothing when folder does not exist', () async {
      await expectLater(repo.delete('nonexistent'), completes);
    });
  });

  // ─── reparent ────────────────────────────────────────────────────────────────

  group('reparent', () {
    test('moves folder to new parent', () async {
      await repo.create(makeFolder(id: 'parent', name: 'Parent'));
      await repo.create(makeFolder(id: 'child', name: 'Child'));

      await repo.reparent('child', 'parent');

      final child = await repo.getById('child');
      expect(child!.parentFolderId, 'parent');
    });

    test('reparents to root when parentId is null', () async {
      await repo.create(makeFolder(id: 'root', name: 'Root'));
      await repo.create(FolderModel(
          id: 'child',
          name: 'Child',
          parentFolderId: 'root',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024)));

      await repo.reparent('child', null);

      final child = await repo.getById('child');
      expect(child!.parentFolderId, isNull);
    });
  });

  // ─── setTags / getTags ───────────────────────────────────────────────────────

  group('setTags and getTags', () {
    test('setTags stores normalised tags', () async {
      await repo.create(makeFolder());
      await repo.setTags('f1', ['Jazz', ' Rock ', 'jazz']);

      final tags = await repo.getTags('f1');
      expect(tags.toSet(), {'jazz', 'rock'});
    });

    test('setTags replaces previous tags', () async {
      await repo.create(makeFolder());
      await repo.setTags('f1', ['Jazz']);
      await repo.setTags('f1', ['Rock']);

      final tags = await repo.getTags('f1');
      expect(tags, ['rock']);
    });

    test('getTags returns empty list when no tags set', () async {
      await repo.create(makeFolder());
      expect(await repo.getTags('f1'), isEmpty);
    });
  });

  // ─── getDepth ────────────────────────────────────────────────────────────────

  group('getDepth', () {
    test('returns 0 for a root folder', () async {
      await repo.create(makeFolder());
      expect(await repo.getDepth('f1'), 0);
    });

    test('returns 1 for a direct child', () async {
      await repo.create(makeFolder(id: 'root', name: 'Root'));
      await repo.create(FolderModel(
          id: 'child',
          name: 'Child',
          parentFolderId: 'root',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024)));

      expect(await repo.getDepth('child'), 1);
    });
  });
}
