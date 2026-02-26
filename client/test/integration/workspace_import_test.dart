// Integration test: workspace setup and database portability.
//
// Creates a temporary workspace directory, sets up the database via
// WorkspaceService, inserts data, then opens a *second* AppDatabase instance
// at the same path and asserts all data is visible — simulating a fresh-install
// restore scenario.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/workspace_service.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

void main() {
  late Directory tempDir;
  late Directory workspaceDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('workspace_import_test_');
    workspaceDir = Directory(path.join(tempDir.path, 'MyScores'));
    await workspaceDir.create();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('workspace database persists across AppDatabase instances', () async {
    // ── Phase 1: Set up workspace and insert data ──────────────────────────
    final wsService = WorkspaceService(overrideBaseDir: tempDir.path);
    await wsService.setWorkspacePath(workspaceDir.path);
    await wsService.ensureSheetshowDir(workspaceDir.path);

    final dbPath = wsService.getDatabasePath(workspaceDir.path);

    // Verify the .sheetshow directory was created
    final sheetshowDir = Directory(path.join(workspaceDir.path, '.sheetshow'));
    expect(await sheetshowDir.exists(), isTrue);

    // Open first database instance and insert a score
    final db1 = AppDatabase.openAt(dbPath);
    final repo1 = ScoreRepository(db1, const SystemClockService());

    await repo1.insert(
      ScoreModel(
        id: 'score-1',
        title: 'Moonlight Sonata',
        filename: 'moonlight.pdf',
        localFilePath: '/workspace/moonlight.pdf',
        totalPages: 8,
        updatedAt: DateTime(2024, 6, 1),
      ),
    );
    await repo1.setTags('score-1', ['classical', 'beethoven']);
    await db1.close();

    // ── Phase 2: Open second instance and verify data ───────────────────────
    final db2 = AppDatabase.openAt(dbPath);
    final repo2 = ScoreRepository(db2, const SystemClockService());

    final restored = await repo2.getById('score-1');
    expect(restored, isNotNull);
    expect(restored!.title, 'Moonlight Sonata');
    expect(restored.totalPages, 8);

    final tags = await repo2.getTags('score-1');
    expect(tags, containsAll(['classical', 'beethoven']));

    await db2.close();
  });

  test('getDatabasePath returns path inside .sheetshow', () {
    final wsService = WorkspaceService(overrideBaseDir: tempDir.path);
    final dbPath = wsService.getDatabasePath(workspaceDir.path);
    expect(dbPath, contains('.sheetshow'));
    expect(dbPath, endsWith('data.db'));
  });

  test('getWorkspacePath returns the configured path', () async {
    final wsService = WorkspaceService(overrideBaseDir: tempDir.path);
    await wsService.setWorkspacePath(workspaceDir.path);
    expect(await wsService.getWorkspacePath(), workspaceDir.path);
  });

  test('in-memory database is usable for testing (NativeDatabase.memory)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = ScoreRepository(db, const SystemClockService());

    await repo.insert(
      ScoreModel(
        id: 'test-score',
        title: 'Test Score',
        filename: 'test.pdf',
        localFilePath: '/test.pdf',
        totalPages: 1,
        updatedAt: DateTime(2024),
      ),
    );

    final score = await repo.getById('test-score');
    expect(score, isNotNull);
    expect(score!.title, 'Test Score');

    await db.close();
  });
}
