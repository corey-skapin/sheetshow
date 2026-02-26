import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/features/library/models/realbook_model.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/realbook_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

void main() {
  late AppDatabase db;
  late RealbookRepository realbookRepo;
  late ScoreRepository scoreRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    realbookRepo = RealbookRepository(db, const SystemClockService());
    scoreRepo = ScoreRepository(db, const SystemClockService());
  });

  tearDown(() async {
    await db.close();
  });

  RealbookModel makeRealbook({
    String id = 'rb1',
    String title = 'The Real Book Vol. 1',
    String filename = 'real-book-v1.pdf',
    String localFilePath = '/music/real-book-v1.pdf',
    int totalPages = 400,
  }) {
    return RealbookModel(
      id: id,
      title: title,
      filename: filename,
      localFilePath: localFilePath,
      totalPages: totalPages,
      updatedAt: DateTime(2024),
    );
  }

  ScoreModel makeRealbookScore({
    String id = 'sc1',
    String realbookId = 'rb1',
    String title = 'Autumn Leaves',
    int startPage = 10,
    int endPage = 12,
  }) {
    return ScoreModel(
      id: id,
      title: title,
      filename: 'real-book-v1.pdf',
      localFilePath: '/music/real-book-v1.pdf',
      totalPages: endPage - startPage + 1,
      updatedAt: DateTime(2024),
      realbookId: realbookId,
      startPage: startPage,
      endPage: endPage,
      realbookTitle: 'The Real Book Vol. 1',
    );
  }

  // ─── CRUD ──────────────────────────────────────────────────────────────────

  group('CRUD', () {
    test('insert and getById', () async {
      final rb = makeRealbook();
      await realbookRepo.insert(rb);

      final result = await realbookRepo.getById('rb1');
      expect(result, isNotNull);
      expect(result!.title, 'The Real Book Vol. 1');
      expect(result.filename, 'real-book-v1.pdf');
      expect(result.totalPages, 400);
    });

    test('getAll returns realbooks with score counts', () async {
      await realbookRepo.insert(makeRealbook());
      await scoreRepo.insert(makeRealbookScore());
      await scoreRepo.insert(makeRealbookScore(
        id: 'sc2',
        title: 'Blue Bossa',
        startPage: 13,
        endPage: 14,
      ));

      final all = await realbookRepo.getAll();
      expect(all.length, 1);
      expect(all.first.scoreCount, 2);
    });

    test('updateTitle changes the title', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.updateTitle('rb1', 'Real Book Volume I');

      final updated = await realbookRepo.getById('rb1');
      expect(updated!.title, 'Real Book Volume I');
    });

    test('isRealbookPath returns true for known paths', () async {
      await realbookRepo.insert(makeRealbook());
      expect(
          await realbookRepo.isRealbookPath('/music/real-book-v1.pdf'), true);
      expect(await realbookRepo.isRealbookPath('/other/file.pdf'), false);
    });
  });

  // ─── Tags ──────────────────────────────────────────────────────────────────

  group('tags', () {
    test('setTags and getTags', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.setTags('rb1', ['jazz', 'standards']);

      final tags = await realbookRepo.getTags('rb1');
      expect(tags, ['jazz', 'standards']);
    });

    test('setTags replaces existing tags', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.setTags('rb1', ['jazz', 'standards']);
      await realbookRepo.setTags('rb1', ['bebop']);

      final tags = await realbookRepo.getTags('rb1');
      expect(tags, ['bebop']);
    });
  });

  // ─── Cascade delete ────────────────────────────────────────────────────────

  group('cascade delete', () {
    test('deleting realbook removes all its scores', () async {
      await realbookRepo.insert(makeRealbook());
      await scoreRepo.insert(makeRealbookScore());
      await scoreRepo.insert(makeRealbookScore(
        id: 'sc2',
        title: 'Blue Bossa',
        startPage: 13,
        endPage: 14,
      ));

      await realbookRepo.delete('rb1');

      expect(await scoreRepo.getById('sc1'), isNull);
      expect(await scoreRepo.getById('sc2'), isNull);
      expect(await realbookRepo.getById('rb1'), isNull);
    });

    test('deleting realbook removes its tags', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.setTags('rb1', ['jazz']);

      await realbookRepo.delete('rb1');

      final tags = await realbookRepo.getTags('rb1');
      expect(tags, isEmpty);
    });
  });

  // ─── Effective tags ────────────────────────────────────────────────────────

  group('effective tags with realbook tags', () {
    test('realbook tags are included in score effective tags', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.setTags('rb1', ['jazz', 'standards']);
      await scoreRepo.insert(makeRealbookScore());
      await scoreRepo.setTags('sc1', ['favorite']);

      final effective = await scoreRepo.getEffectiveTags('sc1');
      expect(effective, containsAll(['jazz', 'standards', 'favorite']));
    });

    test('effective tags are deduplicated', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.setTags('rb1', ['jazz']);
      await scoreRepo.insert(makeRealbookScore());
      await scoreRepo.setTags('sc1', ['jazz']);

      final effective = await scoreRepo.getEffectiveTags('sc1');
      // Should appear only once
      expect(effective.where((t) => t == 'jazz').length, 1);
    });
  });

  // ─── watchAll with realbook filter ─────────────────────────────────────────

  group('watchAll with realbookId', () {
    test('filters scores by realbook', () async {
      await realbookRepo.insert(makeRealbook());
      await realbookRepo.insert(makeRealbook(
        id: 'rb2',
        title: 'Jazz Standards',
        filename: 'standards.pdf',
        localFilePath: '/music/standards.pdf',
      ));
      await scoreRepo.insert(makeRealbookScore());
      await scoreRepo.insert(makeRealbookScore(
        id: 'sc2',
        realbookId: 'rb2',
        title: 'Giant Steps',
        startPage: 5,
        endPage: 7,
      ));

      final scores = await scoreRepo.watchAll(realbookId: 'rb1').first;
      expect(scores.length, 1);
      expect(scores.first.title, 'Autumn Leaves');
    });

    test('includes realbook title in mapped scores', () async {
      await realbookRepo.insert(makeRealbook());
      await scoreRepo.insert(makeRealbookScore());

      final scores = await scoreRepo.watchAll().first;
      final rbScore = scores.firstWhere((s) => s.id == 'sc1');
      expect(rbScore.realbookTitle, 'The Real Book Vol. 1');
      expect(rbScore.isRealbookExcerpt, true);
    });
  });
}
