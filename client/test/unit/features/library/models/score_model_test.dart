import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/library/models/score_model.dart';

void main() {
  final now = DateTime(2024, 1, 15, 10, 30);

  ScoreModel makeScore({
    String id = 'score-1',
    String title = 'Beethoven Op. 27',
    String filename = 'beethoven.pdf',
    String localFilePath = '/local/beethoven.pdf',
    int totalPages = 10,
    String? thumbnailPath,
    String? folderId,
    DateTime? importedAt,
    DateTime? updatedAt,
  }) =>
      ScoreModel(
        id: id,
        title: title,
        filename: filename,
        localFilePath: localFilePath,
        totalPages: totalPages,
        thumbnailPath: thumbnailPath,
        folderId: folderId,
        importedAt: importedAt ?? now,
        updatedAt: updatedAt ?? now,
      );

  group('ScoreModel', () {
    test('constructs with required fields', () {
      final score = makeScore();
      expect(score.id, 'score-1');
      expect(score.title, 'Beethoven Op. 27');
      expect(score.filename, 'beethoven.pdf');
      expect(score.localFilePath, '/local/beethoven.pdf');
      expect(score.totalPages, 10);
    });

    test('constructs with optional fields', () {
      final score = makeScore(
        thumbnailPath: '/thumbnails/beethoven.jpg',
        folderId: 'folder-1',
      );
      expect(score.thumbnailPath, '/thumbnails/beethoven.jpg');
      expect(score.folderId, 'folder-1');
    });

    group('copyWith', () {
      test('returns identical object when no args', () {
        final score = makeScore();
        final copy = score.copyWith();
        expect(copy.id, score.id);
        expect(copy.title, score.title);
        expect(copy.filename, score.filename);
        expect(copy.localFilePath, score.localFilePath);
        expect(copy.totalPages, score.totalPages);
      });

      test('copies with new title', () {
        final score = makeScore();
        final copy = score.copyWith(title: 'Moonlight Sonata');
        expect(copy.title, 'Moonlight Sonata');
        expect(copy.id, score.id);
      });

      test('copies with new folderId', () {
        final score = makeScore();
        final copy = score.copyWith(folderId: 'folder-2');
        expect(copy.folderId, 'folder-2');
      });

      test('copies with thumbnailPath', () {
        final score = makeScore();
        final copy = score.copyWith(thumbnailPath: '/thumb.jpg');
        expect(copy.thumbnailPath, '/thumb.jpg');
      });
    });

    group('equality', () {
      test('equal when same id', () {
        final a = makeScore(id: 'score-1');
        final b = makeScore(id: 'score-1', title: 'Different Title');
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        final a = makeScore(id: 'score-1');
        final b = makeScore(id: 'score-2');
        expect(a, isNot(equals(b)));
      });

      test('identical object equals itself', () {
        final a = makeScore();
        expect(a, equals(a));
      });

      test('hashCode based on id', () {
        final a = makeScore(id: 'score-1');
        final b = makeScore(id: 'score-1');
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
