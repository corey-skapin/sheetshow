import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
    scoreRepo = ScoreRepository(db);
    folderRepo = FolderRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FolderWatchService buildService({
    StreamController<FileSystemEvent>? controller,
    PageCountProvider? pageCountProvider,
  }) {
    final ctrl =
        controller ?? StreamController<FileSystemEvent>.broadcast();
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
      final ctrl = StreamController<FileSystemEvent>();
      final service = buildService(controller: ctrl);

      await service.start(tempDir.path);
      expect(ctrl.hasListener, isTrue);

      service.stop();
      await ctrl.close();
    });

    test('stop cancels the subscription', () async {
      final ctrl = StreamController<FileSystemEvent>.broadcast();
      final service = buildService(controller: ctrl);

      await service.start(tempDir.path);
      service.stop();
      expect(ctrl.hasListener, isFalse);

      await ctrl.close();
    });

    test('calling stop before start does not throw', () {
      final service = buildService();
      expect(() => service.stop(), returnsNormally);
    });
  });

  // ─── Suppression ────────────────────────────────────────────────────────────

  group('suppression', () {
    test('suppress marks path as suppressed', () {
      final service = buildService();
      service.suppress('/music/score.pdf');
      expect(service.isSuppressed('/music/score.pdf'), isTrue);
    });

    test('unsuppress clears suppression', () {
      final service = buildService();
      service.suppress('/music/score.pdf');
      service.unsuppress('/music/score.pdf');
      expect(service.isSuppressed('/music/score.pdf'), isFalse);
    });

    test('suppression is case-insensitive', () {
      final service = buildService();
      service.suppress('/Music/Score.PDF');
      expect(service.isSuppressed('/music/score.pdf'), isTrue);
    });

    test('suppressed PDF create event is skipped', () async {
      final pdfPath = '${tempDir.path}/score.pdf';
      final service = buildService();
      service.suppress(pdfPath);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      expect(await scoreRepo.getByFilename('score.pdf'), isNull);
    });

    test('unsuppressed path is processed normally', () async {
      final pdfPath = '${tempDir.path}/bach.pdf';
      final service = buildService(pageCountProvider: (_) async => 3);
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
      final pdfPath = '${tempDir.path}/beethoven.pdf';
      final service = buildService(pageCountProvider: (_) async => 5);

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
      final service = buildService();

      await service.handleEventForTesting(
        eventPath: '${tempDir.path}/readme.txt',
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      final allScores = await db.select(db.scores).get();
      expect(allScores, isEmpty);
    });

    test('skips PDF when pageCountProvider returns null', () async {
      final pdfPath = '${tempDir.path}/invalid.pdf';
      final service =
          buildService(pageCountProvider: (_) async => null);

      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.create,
      );

      expect(await scoreRepo.getByFilename('invalid.pdf'), isNull);
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

      final service = buildService();
      await service.handleEventForTesting(
        eventPath: pdfPath,
        isDirectory: false,
        kind: WatchEventKind.delete,
      );

      expect(await scoreRepo.getByFilePath(pdfPath), isNull);
    });

    test('does nothing when score does not exist', () async {
      final service = buildService();

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
