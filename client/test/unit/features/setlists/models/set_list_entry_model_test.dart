import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';

void main() {
  final now = DateTime(2024, 5, 20, 14, 0);

  SetListEntryModel makeEntry({
    String id = 'entry-1',
    String setListId = 'setlist-1',
    String scoreId = 'score-1',
    int orderIndex = 0,
    DateTime? addedAt,
  }) =>
      SetListEntryModel(
        id: id,
        setListId: setListId,
        scoreId: scoreId,
        orderIndex: orderIndex,
        addedAt: addedAt ?? now,
      );

  group('SetListEntryModel', () {
    test('constructs with required fields', () {
      final entry = makeEntry();
      expect(entry.id, 'entry-1');
      expect(entry.setListId, 'setlist-1');
      expect(entry.scoreId, 'score-1');
      expect(entry.orderIndex, 0);
    });

    group('copyWith', () {
      test('returns identical object when no args', () {
        final entry = makeEntry();
        final copy = entry.copyWith();
        expect(copy.id, entry.id);
        expect(copy.setListId, entry.setListId);
        expect(copy.scoreId, entry.scoreId);
        expect(copy.orderIndex, entry.orderIndex);
      });

      test('copies with new orderIndex', () {
        final entry = makeEntry();
        final copy = entry.copyWith(orderIndex: 3);
        expect(copy.orderIndex, 3);
        expect(copy.id, entry.id);
      });

      test('copies with new scoreId', () {
        final entry = makeEntry();
        final copy = entry.copyWith(scoreId: 'score-2');
        expect(copy.scoreId, 'score-2');
      });

      test('copies with new setListId', () {
        final entry = makeEntry();
        final copy = entry.copyWith(setListId: 'setlist-2');
        expect(copy.setListId, 'setlist-2');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final entry = makeEntry(
          id: 'entry-1',
          setListId: 'setlist-1',
          scoreId: 'score-1',
          orderIndex: 2,
          addedAt: now,
        );
        final json = entry.toJson();
        expect(json['id'], 'entry-1');
        expect(json['setListId'], 'setlist-1');
        expect(json['scoreId'], 'score-1');
        expect(json['orderIndex'], 2);
        expect(json['addedAt'], now.toIso8601String());
      });
    });

    group('fromJson', () {
      test('deserializes from JSON', () {
        final json = {
          'id': 'entry-2',
          'setListId': 'setlist-1',
          'scoreId': 'score-3',
          'orderIndex': 1,
          'addedAt': now.toIso8601String(),
        };
        final entry = SetListEntryModel.fromJson(json);
        expect(entry.id, 'entry-2');
        expect(entry.setListId, 'setlist-1');
        expect(entry.scoreId, 'score-3');
        expect(entry.orderIndex, 1);
      });

      test('handles missing addedAt', () {
        const json = <String, dynamic>{
          'id': 'entry-3',
          'setListId': 'setlist-1',
          'scoreId': 'score-4',
          'orderIndex': 0,
        };
        expect(() => SetListEntryModel.fromJson(json), returnsNormally);
      });
    });
  });
}
