import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
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
    SyncState syncState = SyncState.synced,
    String? cloudId,
    int serverVersion = 0,
    bool isDeleted = false,
  }) =>
      SetListModel(
        id: id,
        name: name,
        entries: entries ?? [],
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
        syncState: syncState,
        cloudId: cloudId,
        serverVersion: serverVersion,
        isDeleted: isDeleted,
      );

  group('SetListModel', () {
    test('constructs with required fields', () {
      final setList = makeSetList();
      expect(setList.id, 'setlist-1');
      expect(setList.name, 'Sunday Service');
      expect(setList.entries, isEmpty);
      expect(setList.syncState, SyncState.synced);
      expect(setList.serverVersion, 0);
      expect(setList.isDeleted, false);
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
        expect(copy.syncState, setList.syncState);
        expect(copy.serverVersion, setList.serverVersion);
        expect(copy.isDeleted, setList.isDeleted);
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

      test('copies with syncState', () {
        final setList = makeSetList();
        final copy = setList.copyWith(syncState: SyncState.pendingDelete);
        expect(copy.syncState, SyncState.pendingDelete);
      });

      test('copies with cloudId and serverVersion', () {
        final setList = makeSetList();
        final copy = setList.copyWith(cloudId: 'cloud-1', serverVersion: 4);
        expect(copy.cloudId, 'cloud-1');
        expect(copy.serverVersion, 4);
      });

      test('copies with isDeleted', () {
        final setList = makeSetList();
        final copy = setList.copyWith(isDeleted: true);
        expect(copy.isDeleted, true);
      });
    });

    group('toJson', () {
      test('serializes required fields', () {
        final setList = makeSetList(
          id: 'setlist-1',
          name: 'Sunday Service',
          updatedAt: now,
        );
        final json = setList.toJson();
        expect(json['id'], 'setlist-1');
        expect(json['name'], 'Sunday Service');
        expect(json['entries'], isEmpty);
        expect(json['updatedAt'], now.toIso8601String());
        expect(json['cloudId'], isNull);
        expect(json['serverVersion'], 0);
      });

      test('serializes entries', () {
        final entries = [makeEntry(id: 'entry-1')];
        final setList = makeSetList(entries: entries);
        final json = setList.toJson();
        final entriesJson = json['entries'] as List;
        expect(entriesJson, hasLength(1));
        expect(entriesJson.first['id'], 'entry-1');
      });

      test('serializes optional fields', () {
        final setList = makeSetList(cloudId: 'cloud-2', serverVersion: 7);
        final json = setList.toJson();
        expect(json['cloudId'], 'cloud-2');
        expect(json['serverVersion'], 7);
      });
    });

    group('fromJson', () {
      test('deserializes from JSON', () {
        final json = {
          'id': 'setlist-2',
          'name': 'Rehearsal',
          'entries': <Map<String, dynamic>>[],
          'cloudId': 'cloud-setlist-2',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'serverVersion': 2,
        };
        final setList = SetListModel.fromJson(json);
        expect(setList.id, 'setlist-2');
        expect(setList.name, 'Rehearsal');
        expect(setList.entries, isEmpty);
        expect(setList.syncState, SyncState.synced);
        expect(setList.cloudId, 'cloud-setlist-2');
        expect(setList.serverVersion, 2);
      });

      test('deserializes with entries', () {
        final json = {
          'id': 'setlist-3',
          'name': 'Concert',
          'entries': [
            {
              'id': 'entry-1',
              'setListId': 'setlist-3',
              'scoreId': 'score-1',
              'orderIndex': 0,
              'addedAt': now.toIso8601String(),
            }
          ],
          'updatedAt': now.toIso8601String(),
        };
        final setList = SetListModel.fromJson(json);
        expect(setList.entries, hasLength(1));
        expect(setList.entries.first.scoreId, 'score-1');
      });

      test('handles missing optional fields', () {
        const json = <String, dynamic>{
          'id': 'setlist-4',
          'name': 'Empty',
        };
        final setList = SetListModel.fromJson(json);
        expect(setList.id, 'setlist-4');
        expect(setList.entries, isEmpty);
        expect(setList.serverVersion, 0);
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
