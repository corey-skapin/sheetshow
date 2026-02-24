import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/sync/models/sync_status.dart';

void main() {
  final syncedAt = DateTime(2024, 10, 1, 12, 0);

  group('SyncStatus', () {
    test('default state is idle', () {
      const status = SyncStatus();
      expect(status.state, SyncUiState.idle);
      expect(status.lastSyncAt, isNull);
      expect(status.pendingConflictCount, 0);
      expect(status.errorMessage, isNull);
    });

    test('constructs with all fields', () {
      final status = SyncStatus(
        state: SyncUiState.syncing,
        lastSyncAt: syncedAt,
        pendingConflictCount: 3,
        errorMessage: 'oops',
      );
      expect(status.state, SyncUiState.syncing);
      expect(status.lastSyncAt, syncedAt);
      expect(status.pendingConflictCount, 3);
      expect(status.errorMessage, 'oops');
    });

    group('copyWith', () {
      test('returns same values when no args provided', () {
        const original = SyncStatus();
        final copy = original.copyWith();
        expect(copy.state, original.state);
        expect(copy.pendingConflictCount, original.pendingConflictCount);
        expect(copy.errorMessage, original.errorMessage);
      });

      test('copies with new state', () {
        const original = SyncStatus();
        final copy = original.copyWith(state: SyncUiState.offline);
        expect(copy.state, SyncUiState.offline);
      });

      test('copies with new lastSyncAt', () {
        const original = SyncStatus();
        final copy = original.copyWith(lastSyncAt: syncedAt);
        expect(copy.lastSyncAt, syncedAt);
      });

      test('copies with new pendingConflictCount', () {
        const original = SyncStatus();
        final copy = original.copyWith(pendingConflictCount: 5);
        expect(copy.pendingConflictCount, 5);
      });

      test('errorMessage is cleared when not provided in copyWith', () {
        final original = const SyncStatus().copyWith(
          state: SyncUiState.error,
          errorMessage: 'some error',
        );
        // copyWith with no errorMessage passes null explicitly
        final copy = original.copyWith(state: SyncUiState.idle);
        expect(copy.errorMessage, isNull);
      });
    });
  });

  group('SyncUiState enum', () {
    test('has expected values', () {
      expect(SyncUiState.values, hasLength(5));
      expect(SyncUiState.values, contains(SyncUiState.idle));
      expect(SyncUiState.values, contains(SyncUiState.syncing));
      expect(SyncUiState.values, contains(SyncUiState.conflict));
      expect(SyncUiState.values, contains(SyncUiState.offline));
      expect(SyncUiState.values, contains(SyncUiState.error));
    });
  });

  group('SyncStatusNotifier', () {
    late ProviderContainer container;
    late SyncStatusNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(syncStatusProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('initial state is idle', () {
      final status = container.read(syncStatusProvider);
      expect(status.state, SyncUiState.idle);
    });

    test('setSyncing sets state to syncing', () {
      notifier.setSyncing();
      expect(container.read(syncStatusProvider).state, SyncUiState.syncing);
    });

    test('setIdle sets state to idle and records lastSyncAt', () {
      notifier.setSyncing();
      notifier.setIdle(syncedAt);
      final status = container.read(syncStatusProvider);
      expect(status.state, SyncUiState.idle);
      expect(status.lastSyncAt, syncedAt);
    });

    test('setOffline sets state to offline', () {
      notifier.setOffline();
      expect(container.read(syncStatusProvider).state, SyncUiState.offline);
    });

    test('setError sets state to error with message', () {
      notifier.setError('connection failed');
      final status = container.read(syncStatusProvider);
      expect(status.state, SyncUiState.error);
      expect(status.errorMessage, 'connection failed');
    });

    test('setConflict sets state to conflict with count', () {
      notifier.setConflict(4);
      final status = container.read(syncStatusProvider);
      expect(status.state, SyncUiState.conflict);
      expect(status.pendingConflictCount, 4);
    });

    test('setQuotaExceeded sets error state with quota message', () {
      notifier.setQuotaExceeded();
      final status = container.read(syncStatusProvider);
      expect(status.state, SyncUiState.error);
      expect(status.errorMessage, contains('storage'));
    });

    test('setMaxRetriesExhausted sets error state with retry message', () {
      notifier.setMaxRetriesExhausted('score-1 failed');
      final status = container.read(syncStatusProvider);
      expect(status.state, SyncUiState.error);
      expect(status.errorMessage, contains('retries'));
      expect(status.errorMessage, contains('score-1 failed'));
    });
  });
}
