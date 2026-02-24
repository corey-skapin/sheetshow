import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
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
    SyncState syncState = SyncState.synced,
    String? cloudId,
    int serverVersion = 0,
    bool isDeleted = false,
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
        syncState: syncState,
        cloudId: cloudId,
        serverVersion: serverVersion,
        isDeleted: isDeleted,
      );

  group('ScoreModel', () {
    test('constructs with required fields', () {
      final score = makeScore();
      expect(score.id, 'score-1');
      expect(score.title, 'Beethoven Op. 27');
      expect(score.filename, 'beethoven.pdf');
      expect(score.localFilePath, '/local/beethoven.pdf');
      expect(score.totalPages, 10);
      expect(score.syncState, SyncState.synced);
      expect(score.serverVersion, 0);
      expect(score.isDeleted, false);
    });

    test('constructs with optional fields', () {
      final score = makeScore(
        thumbnailPath: '/thumbnails/beethoven.jpg',
        folderId: 'folder-1',
        cloudId: 'cloud-abc',
        serverVersion: 3,
        isDeleted: true,
      );
      expect(score.thumbnailPath, '/thumbnails/beethoven.jpg');
      expect(score.folderId, 'folder-1');
      expect(score.cloudId, 'cloud-abc');
      expect(score.serverVersion, 3);
      expect(score.isDeleted, true);
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
        expect(copy.syncState, score.syncState);
        expect(copy.serverVersion, score.serverVersion);
        expect(copy.isDeleted, score.isDeleted);
      });

      test('copies with new title', () {
        final score = makeScore();
        final copy = score.copyWith(title: 'Moonlight Sonata');
        expect(copy.title, 'Moonlight Sonata');
        expect(copy.id, score.id);
      });

      test('copies with new syncState', () {
        final score = makeScore();
        final copy = score.copyWith(syncState: SyncState.pendingUpload);
        expect(copy.syncState, SyncState.pendingUpload);
      });

      test('copies with new folderId', () {
        final score = makeScore();
        final copy = score.copyWith(folderId: 'folder-2');
        expect(copy.folderId, 'folder-2');
      });

      test('copies with cloudId', () {
        final score = makeScore();
        final copy = score.copyWith(cloudId: 'cloud-xyz', serverVersion: 5);
        expect(copy.cloudId, 'cloud-xyz');
        expect(copy.serverVersion, 5);
      });

      test('copies with isDeleted', () {
        final score = makeScore();
        final copy = score.copyWith(isDeleted: true);
        expect(copy.isDeleted, true);
      });
    });

    group('toJson', () {
      test('serializes required fields', () {
        final score = makeScore(
          id: 'score-1',
          title: 'Beethoven',
          filename: 'beethoven.pdf',
          totalPages: 10,
          updatedAt: now,
        );
        final json = score.toJson();
        expect(json['id'], 'score-1');
        expect(json['title'], 'Beethoven');
        expect(json['filename'], 'beethoven.pdf');
        expect(json['totalPages'], 10);
        expect(json['updatedAt'], now.toIso8601String());
        expect(json['cloudId'], isNull);
        expect(json['serverVersion'], 0);
        expect(json['folderId'], isNull);
      });

      test('serializes optional fields', () {
        final score = makeScore(
          folderId: 'folder-1',
          cloudId: 'cloud-1',
          serverVersion: 2,
        );
        final json = score.toJson();
        expect(json['folderId'], 'folder-1');
        expect(json['cloudId'], 'cloud-1');
        expect(json['serverVersion'], 2);
      });
    });

    group('fromJson', () {
      test('deserializes from JSON', () {
        final json = {
          'id': 'score-2',
          'title': 'Chopin',
          'filename': 'chopin.pdf',
          'totalPages': 8,
          'folderId': 'folder-1',
          'cloudId': 'cloud-score-2',
          'updatedAt': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'serverVersion': 3,
        };
        final score = ScoreModel.fromJson(json);
        expect(score.id, 'score-2');
        expect(score.title, 'Chopin');
        expect(score.filename, 'chopin.pdf');
        expect(score.totalPages, 8);
        expect(score.folderId, 'folder-1');
        expect(score.syncState, SyncState.synced);
        expect(score.cloudId, 'cloud-score-2');
        expect(score.serverVersion, 3);
        expect(score.localFilePath, '');
      });

      test('handles missing optional fields', () {
        const json = <String, dynamic>{
          'id': 'score-3',
          'title': 'Bach',
          'filename': 'bach.pdf',
        };
        final score = ScoreModel.fromJson(json);
        expect(score.id, 'score-3');
        expect(score.totalPages, 0);
        expect(score.folderId, isNull);
        expect(score.serverVersion, 0);
      });

      test('handles invalid date strings gracefully', () {
        const json = <String, dynamic>{
          'id': 'score-4',
          'title': 'Mozart',
          'filename': 'mozart.pdf',
          'updatedAt': 'not-a-date',
          'createdAt': '',
        };
        expect(() => ScoreModel.fromJson(json), returnsNormally);
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
