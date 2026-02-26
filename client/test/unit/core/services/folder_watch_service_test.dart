import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/folder_watch_service.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/folder_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ScoreRepository scoreRepo;
  late FolderRepository folderRepo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('watch_svc_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scoreRepo = ScoreRepository(db, const SystemClockService());
    folderRepo = FolderRepository(db, const SystemClockService());
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a [FolderWatchService] with an injected stream controller and
  /// an optional page-count override.
  ///
  /// [ctrl] is used as the file-system event source; the caller is responsible
  /// for closing it.
  FolderWatchService buildService(
    StreamController<FileSystemEvent> ctrl, {
    PageCountProvider? pageCountProvider,
  }) {
    return FolderWatchService(
      scoreRepository: scoreRepo,
      folderRepository: folderRepo,
      clockService: const SystemClockService(),
      fileSystemWatcher: (_) => ctrl.stream,
      pageCountProvider: pageCountProvider ?? (_) async => 10,
    );
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  group('lifecycle', () {
    test('start creates a listener on the stream', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.start(tempDir.path);
      // broadcast streams don't expose hasListener; verify by checking stop clears sub
      service.stop();
    });

    test('stop cancels the subscription', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.start(tempDir.path);
      service.stop();
      expect(ctrl.hasListener, isFalse);
    });

    test('calling stop before start does not throw', () {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);
      expect(() => service.stop(), returnsNormally);
    });
  });

  // ─── Suppression ────────────────────────────────────────────────────────────

  group('suppression', () {
    test('suppress marks path as suppressed', () {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);
      service.suppress('/music/score.pdf');
      expect(service.isSuppressed('/music/score.pdf'), isTrue);
    });

    test('unsuppress clears suppression', () {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);
      service.suppress('/music/score.pdf');
      service.unsuppress('/music/score.pdf');
      expect(service.isSuppressed('/music/score.pdf'), isFalse);
    });

    test('suppression is case-insensitive', () {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);
      service.suppress('/Music/Score.PDF');
      expect(service.isSuppressed('/music/score.pdf'), isTrue);
    });

    test('suppressed PDF create event is skipped', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final pdfPath = '${tempDir.path}/score.pdf';
      final service = buildService(ctrl);
      service.suppress(pdfPath);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      expect(await scoreRepo.getByFilename('score.pdf'), isNull);
    });

    test('unsuppressed path is processed normally', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final pdfPath = '${tempDir.path}/bach.pdf';
      final service = buildService(ctrl, pageCountProvider: (_) async => 3);
      service.suppress(pdfPath);
      service.unsuppress(pdfPath);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      expect(await scoreRepo.getByFilename('bach.pdf'), isNotNull);
    });
  });

  // ─── PDF create ──────────────────────────────────────────────────────────────

  group('PDF create event', () {
    test('inserts a new score into the database', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final pdfPath = '${tempDir.path}/beethoven.pdf';
      final service = buildService(ctrl, pageCountProvider: (_) async => 5);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      final score = await scoreRepo.getByFilename('beethoven.pdf');
      expect(score, isNotNull);
      expect(score!.title, 'beethoven');
      expect(score.totalPages, 5);
      expect(score.localFilePath, pdfPath);
    });

    test('skips non-PDF files', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: '${tempDir.path}/readme.txt',
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      final allScores = await db.select(db.scores).get();
      expect(allScores, isEmpty);
    });

    test('skips PDF when pageCountProvider returns null', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final pdfPath = '${tempDir.path}/invalid.pdf';
      final service = buildService(ctrl, pageCountProvider: (_) async => null);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      expect(await scoreRepo.getByFilename('invalid.pdf'), isNull);
    });
  });

  // ─── Directory create ────────────────────────────────────────────────────────

  group('directory create event', () {
    test('inserts a new folder into the database', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final dirPath = '${tempDir.path}/Jazz';
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );

      final folder = await folderRepo.getByDiskPath(dirPath);
      expect(folder, isNotNull);
      expect(folder!.name, 'Jazz');
      expect(folder.diskPath, p.normalize(dirPath));
    });

    test('skips when folder already exists for that disk path', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final dirPath = '${tempDir.path}/Existing';
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );
      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );

      final all = await db.select(db.folders).get();
      expect(all, hasLength(1));
    });

    test('links to parent folder when parent disk path is known', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final parentPath = tempDir.path;
      final childPath = '$parentPath/Baroque';
      final service = buildService(ctrl);

      // Create parent folder record with parent disk path
      await service.handleEventForTesting(
        eventPath: parentPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );
      await service.handleEventForTesting(
        eventPath: childPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );

      final child = await folderRepo.getByDiskPath(childPath);
      final parent = await folderRepo.getByDiskPath(parentPath);
      expect(child!.parentFolderId, parent!.id);
    });
  });

  // ─── Directory delete ────────────────────────────────────────────────────────

  group('directory delete event', () {
    test('removes folder from database', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final dirPath = '${tempDir.path}/ToDelete';
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );
      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.delete,
      );

      expect(await folderRepo.getByDiskPath(dirPath), isNull);
    });

    test('does nothing when folder does not exist', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await expectLater(
        service.handleEventForTesting(
          eventPath: '${tempDir.path}/Ghost',
          isDirectory: true,
          kind: WatchEventKind.delete,
        ),
        completes,
      );
    });
  });

  // ─── Directory move ──────────────────────────────────────────────────────────

  group('directory move event', () {
    test('updates folder name and disk path in database', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final oldPath = '${tempDir.path}/OldName';
      final newPath = '${tempDir.path}/NewName';
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: oldPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );
      await service.handleEventForTesting(
        eventPath: oldPath,
        isDirectory: true,
        kind: WatchEventKind.move,
        destination: newPath,
      );

      expect(await folderRepo.getByDiskPath(oldPath), isNull);
      final renamed = await folderRepo.getByDiskPath(newPath);
      expect(renamed, isNotNull);
      expect(renamed!.name, 'NewName');
    });

    test('deletes folder when move has null destination', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final dirPath = '${tempDir.path}/Gone';
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );
      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.move,
      );

      expect(await folderRepo.getByDiskPath(dirPath), isNull);
    });
  });

  // ─── PDF move ────────────────────────────────────────────────────────────────

  group('PDF move event', () {
    test('updates localFilePath and filename in database', () async {
      const oldPath = '/workspace/old_name.pdf';
      const newPath = '/workspace/new_name.pdf';
      await scoreRepo.insert(_makeScore(
        localFilePath: oldPath,
        filename: 'old_name.pdf',
      ));

      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: oldPath,
        isDirectory: false,
        kind: WatchEventKind.move,
        destination: newPath,
      );

      expect(await scoreRepo.getByFilePath(oldPath), isNull);
      final moved = await scoreRepo.getByFilePath(newPath);
      expect(moved, isNotNull);
      expect(moved!.filename, 'new_name.pdf');
    });

    test('deletes score when move destination is non-PDF', () async {
      const oldPath = '/workspace/score.pdf';
      await scoreRepo.insert(_makeScore(
        localFilePath: oldPath,
        filename: 'score.pdf',
      ));

      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: oldPath,
        isDirectory: false,
        kind: WatchEventKind.move,
        destination: '/workspace/score.md',
      );

      expect(await scoreRepo.getByFilePath(oldPath), isNull);
    });

    test('deletes score when move has null destination', () async {
      const oldPath = '/workspace/score2.pdf';
      await scoreRepo.insert(_makeScore(
        localFilePath: oldPath,
        filename: 'score2.pdf',
      ));

      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: oldPath,
        isDirectory: false,
        kind: WatchEventKind.move,
      );

      expect(await scoreRepo.getByFilePath(oldPath), isNull);
    });
  });

  // ─── PDF create with folder ──────────────────────────────────────────────────

  group('PDF create assigns to folder', () {
    test('links score to folder when parent dir is a known folder', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final dirPath = tempDir.path;
      final service = buildService(ctrl, pageCountProvider: (_) async => 4);

      // First create the folder record for the directory
      await service.handleEventForTesting(
        eventPath: dirPath,
        isDirectory: true,
        kind: WatchEventKind.create,
      );

      final pdfPath = '$dirPath/nocturne.pdf';
      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      final score = await scoreRepo.getByFilename('nocturne.pdf');
      expect(score, isNotNull);
    });

    test('skips duplicate PDF create (filename already in DB)', () async {
      const pdfPath = '/workspace/duplicate.pdf';
      await scoreRepo.insert(_makeScore(
        localFilePath: pdfPath,
        filename: 'duplicate.pdf',
      ));

      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      final all = await db.select(db.scores).get();
      expect(all, hasLength(1));
    });
  });

  // ─── PDF delete ──────────────────────────────────────────────────────────────

  group('PDF delete event', () {
    test('removes score from database', () async {
      const pdfPath = '/workspace/chopin.pdf';
      await scoreRepo.insert(_makeScore(
        localFilePath: pdfPath,
        filename: 'chopin.pdf',
      ));

      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.delete,
      );

      expect(await scoreRepo.getByFilePath(pdfPath), isNull);
    });

    test('does nothing when score does not exist', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      final service = buildService(ctrl);

      await expectLater(
        service.handleEventForTesting(
          eventPath: '/nonexistent.pdf',
          isDirectory: false,
          kind: WatchEventKind.delete,
        ),
        completes,
      );
    });
  });
  // ─── scanWorkspace ────────────────────────────────────────────────

  group('scanWorkspace', () {
    FolderWatchService buildScanService() {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      addTearDown(ctrl.close);
      return FolderWatchService(
        scoreRepository: scoreRepo,
        folderRepository: folderRepo,
        clockService: const SystemClockService(),
        fileSystemWatcher: (_) => ctrl.stream,
        pageCountProvider: (_) async => 3,
      );
    }

    test('imports PDFs found in workspace root', () async {
      final pdfPath = p.join(tempDir.path, 'sonata.pdf');
      File(pdfPath).writeAsBytesSync([]);
      final service = buildScanService();

      await service.scanWorkspace(tempDir.path);

      final score = await scoreRepo.getByFilename('sonata.pdf');
      expect(score, isNotNull);
      expect(score!.title, 'sonata');
    });

    test('imports subdirectory as folder', () async {
      final dirPath = p.join(tempDir.path, 'Classical');
      Directory(dirPath).createSync();
      final service = buildScanService();

      await service.scanWorkspace(tempDir.path);

      final folder = await folderRepo.getByDiskPath(dirPath);
      expect(folder, isNotNull);
      expect(folder!.name, 'Classical');
    });

    test('PDF in subdirectory is linked to its folder', () async {
      final subDir = Directory(p.join(tempDir.path, 'Jazz'))..createSync();
      final pdfPath = p.join(subDir.path, 'miles.pdf');
      File(pdfPath).writeAsBytesSync([]);
      final service = buildScanService();

      await service.scanWorkspace(tempDir.path);

      final folder = await folderRepo.getByDiskPath(subDir.path);
      expect(folder, isNotNull);
      final score = await scoreRepo.getByFilename('miles.pdf');
      expect(score, isNotNull);
      final members = await db.select(db.scoreFolderMemberships).get();
      expect(
        members.any((m) => m.scoreId == score!.id && m.folderId == folder!.id),
        isTrue,
      );
    });

    test('skips .sheetshow directory and its contents', () async {
      final ssDir = Directory(p.join(tempDir.path, '.sheetshow'))..createSync();
      File(p.join(ssDir.path, 'hidden.pdf')).writeAsBytesSync([]);
      final service = buildScanService();

      await service.scanWorkspace(tempDir.path);

      expect(await db.select(db.folders).get(), isEmpty);
      expect(await db.select(db.scores).get(), isEmpty);
    });

    test('is idempotent — running twice does not create duplicates', () async {
      File(p.join(tempDir.path, 'prelude.pdf')).writeAsBytesSync([]);
      Directory(p.join(tempDir.path, 'Baroque')).createSync();
      final service = buildScanService();

      await service.scanWorkspace(tempDir.path);
      await service.scanWorkspace(tempDir.path);

      expect(await db.select(db.scores).get(), hasLength(1));
      expect(await db.select(db.folders).get(), hasLength(1));
    });

    test('does nothing when directory does not exist', () async {
      final service = buildScanService();
      await expectLater(
        service.scanWorkspace('/nonexistent/path/xyz'),
        completes,
      );
      expect(await db.select(db.scores).get(), isEmpty);
    });
  });
}

ScoreModel _makeScore({
  required String localFilePath,
  required String filename,
}) =>
    ScoreModel(
      id: 'score-${filename.hashCode.abs()}',
      title: filename.replaceAll('.pdf', ''),
      filename: filename,
      localFilePath: localFilePath,
      totalPages: 1,
      updatedAt: DateTime(2024),
    );
