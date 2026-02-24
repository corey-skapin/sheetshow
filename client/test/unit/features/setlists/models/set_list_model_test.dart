import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';
import 'package:sheetshow/features/setlists/models/set_list_model.dart';

void main() {
  final now = DateTime(2024, 6, 1, 8, 0);

  SetListEntryModel makeEntry({
    String id = 'entry-1',
    String setListId = 'setlist-1',
    String scoreId = 'score-1',
    int orderIndex = 0,
  }) =>
      SetListEntryModel(
        id: id,
        setListId: setListId,
        scoreId: scoreId,
        orderIndex: orderIndex,
        addedAt: now,
      );

  SetListModel makeSetList({
    String id = 'setlist-1',
    String name = 'Sunday Service',
    List<SetListEntryModel>? entries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SetListModel(
        id: id,
        name: name,
        entries: entries ?? [],
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
      );

  group('SetListModel', () {
    test('constructs with required fields', () {
      final setList = makeSetList();
      expect(setList.id, 'setlist-1');
      expect(setList.name, 'Sunday Service');
      expect(setList.entries, isEmpty);
    });

    test('constructs with entries', () {
      final entries = [makeEntry(), makeEntry(id: 'entry-2', orderIndex: 1)];
      final setList = makeSetList(entries: entries);
      expect(setList.entries, hasLength(2));
    });

    group('copyWith', () {
      test('returns identical object when no args', () {
        final setList = makeSetList();
        final copy = setList.copyWith();
        expect(copy.id, setList.id);
        expect(copy.name, setList.name);
        expect(copy.entries, isEmpty);
      });

      test('copies with new name', () {
        final setList = makeSetList();
        final copy = setList.copyWith(name: 'Christmas Concert');
        expect(copy.name, 'Christmas Concert');
        expect(copy.id, setList.id);
      });

      test('copies with entries', () {
        final setList = makeSetList();
        final entries = [makeEntry()];
        final copy = setList.copyWith(entries: entries);
        expect(copy.entries, hasLength(1));
      });
    });

    group('equality', () {
      test('equal when same id', () {
        final a = makeSetList(id: 'setlist-1');
        final b = makeSetList(id: 'setlist-1', name: 'Different Name');
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        final a = makeSetList(id: 'setlist-1');
        final b = makeSetList(id: 'setlist-2');
        expect(a, isNot(equals(b)));
      });

      test('identical object equals itself', () {
        final a = makeSetList();
        expect(a, equals(a));
      });

      test('hashCode based on id', () {
        final a = makeSetList(id: 'setlist-1');
        final b = makeSetList(id: 'setlist-1');
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
