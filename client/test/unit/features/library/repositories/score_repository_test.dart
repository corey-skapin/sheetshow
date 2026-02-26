import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ScoreRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('score_repo_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ScoreRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<File> createTempPdf(String name) async {
    final file = File(path.join(tempDir.path, name));
    await file.writeAsString('dummy pdf content');
    return file;
  }

  ScoreModel makeScore({
    String id = 's1',
    String title = 'Moonlight Sonata',
    String filename = 'Moonlight Sonata.pdf',
    String? localFilePath,
  }) {
    final filePath = localFilePath ?? path.join(tempDir.path, filename);
    return ScoreModel(
      id: id,
      title: title,
      filename: filename,
      localFilePath: filePath,
      totalPages: 4,
      updatedAt: DateTime(2024),
    );
  }

  // ─── update — title unchanged ────────────────────────────────────────────────

  group('update when title is unchanged', () {
    test('does not rename file on disk', () async {
      final file = await createTempPdf('Moonlight Sonata.pdf');
      await repo.insert(makeScore(localFilePath: file.path));

      await repo.update(makeScore(localFilePath: file.path));

      expect(await file.exists(), isTrue);
    });

    test('updates thumbnailPath in DB', () async {
      final file = await createTempPdf('Moonlight Sonata.pdf');
      final score = makeScore(localFilePath: file.path);
      await repo.insert(score);

      await repo.update(score.copyWith(thumbnailPath: '/thumbs/s1.png'));

      final updated = await repo.getById('s1');
      expect(updated!.thumbnailPath, '/thumbs/s1.png');
    });
  });

  // ─── update — title changed ──────────────────────────────────────────────────

  group('update when title changes', () {
    test('renames PDF on disk', () async {
      final file = await createTempPdf('Moonlight Sonata.pdf');
      await repo.insert(makeScore(localFilePath: file.path));

      await repo.update(makeScore(title: 'Ode to Joy'));

      expect(await file.exists(), isFalse);
      expect(
        await File(path.join(tempDir.path, 'Ode to Joy.pdf')).exists(),
        isTrue,
      );
    });

    test('updates local_file_path and filename in DB', () async {
      final file = await createTempPdf('Moonlight Sonata.pdf');
      await repo.insert(makeScore(localFilePath: file.path));

      await repo.update(makeScore(title: 'Ode to Joy'));

      final updated = await repo.getById('s1');
      expect(updated!.filename, 'Ode to Joy.pdf');
      expect(updated.localFilePath, path.join(tempDir.path, 'Ode to Joy.pdf'));
    });

    test('only updates DB when file does not exist on disk', () async {
      await repo.insert(makeScore(
        localFilePath: '/nonexistent/Moonlight Sonata.pdf',
      ));

      await expectLater(
        repo.update(makeScore(
          title: 'Ode to Joy',
          localFilePath: '/nonexistent/Moonlight Sonata.pdf',
        )),
        completes,
      );

      final updated = await repo.getById('s1');
      expect(updated!.title, 'Ode to Joy');
    });
  });

  // ─── updateFilePath ──────────────────────────────────────────────────────────

  group('updateFilePath', () {
    test('updates local_file_path and filename in DB', () async {
      await repo.insert(makeScore());

      await repo.updateFilePath('s1', '/new/path/renamed.pdf', 'renamed.pdf');

      final updated = await repo.getById('s1');
      expect(updated!.localFilePath, '/new/path/renamed.pdf');
      expect(updated.filename, 'renamed.pdf');
    });
  });

  // ─── getByFilePath ───────────────────────────────────────────────────────────

  group('getByFilePath', () {
    test('returns score with matching localFilePath', () async {
      final score = makeScore();
      await repo.insert(score);

      final result = await repo.getByFilePath(score.localFilePath);
      expect(result, isNotNull);
      expect(result!.id, 's1');
    });

    test('returns null when no score has that path', () async {
      expect(await repo.getByFilePath('/no/such/path.pdf'), isNull);
    });
  });

  // ─── delete ──────────────────────────────────────────────────────────────────

  group('delete', () {
    test('removes score from database', () async {
      await repo.insert(makeScore());
      await repo.delete('s1');
      expect(await repo.getById('s1'), isNull);
    });

    test('does nothing when score does not exist', () async {
      await expectLater(repo.delete('nonexistent'), completes);
    });
  });

  // ─── addToFolder / removeFromFolder ──────────────────────────────────────────

  group('addToFolder and removeFromFolder', () {
    test('addToFolder creates membership', () async {
      await db.into(db.folders).insert(FoldersCompanion.insert(
            id: 'f1',
            name: 'Jazz',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ));
      await repo.insert(makeScore());
      await repo.addToFolder('s1', 'f1');

      final memberships = await db.select(db.scoreFolderMemberships).get();
      expect(memberships, hasLength(1));
    });

    test('removeFromFolder removes membership', () async {
      await db.into(db.folders).insert(FoldersCompanion.insert(
            id: 'f1',
            name: 'Jazz',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ));
      await repo.insert(makeScore());
      await repo.addToFolder('s1', 'f1');
      await repo.removeFromFolder('s1', 'f1');

      final memberships = await db.select(db.scoreFolderMemberships).get();
      expect(memberships, isEmpty);
    });
  });

  // ─── setTags / getTags ───────────────────────────────────────────────────────

  group('setTags and getTags', () {
    test('setTags stores normalised tags', () async {
      await repo.insert(makeScore());
      await repo.setTags('s1', ['Jazz', ' Rock ', 'jazz']);

      final tags = await repo.getTags('s1');
      expect(tags.toSet(), {'jazz', 'rock'});
    });

    test('setTags replaces existing tags', () async {
      await repo.insert(makeScore());
      await repo.setTags('s1', ['Jazz']);
      await repo.setTags('s1', ['Rock']);

      final tags = await repo.getTags('s1');
      expect(tags, ['rock']);
    });

    test('getTags returns empty list when no tags', () async {
      await repo.insert(makeScore());
      expect(await repo.getTags('s1'), isEmpty);
    });
  });

  // ─── getEffectiveTags ────────────────────────────────────────────────────────

  group('getEffectiveTags', () {
    test('merges own tags with folder tags', () async {
      await db.into(db.folders).insert(FoldersCompanion.insert(
            id: 'f1',
            name: 'Classical',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ));
      await repo.insert(makeScore(), folderId: 'f1');
      await repo.setTags('s1', ['solo']);
      await db.into(db.folderTags).insert(
            FolderTagsCompanion.insert(folderId: 'f1', tag: 'baroque'),
          );

      final tags = await repo.getEffectiveTags('s1');
      expect(tags.toSet(), {'solo', 'baroque'});
    });
  });
}
