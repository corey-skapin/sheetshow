import 'package:flutter_riverpod/flutter_riverpod.dart';

// T078: SyncStatus — exposes sync state to the UI via StateNotifier.

/// Current state of the sync engine.
enum SyncState {
  idle,
  syncing,
  conflict,
  offline,
  error,
}

/// Status model for the sync UI indicator.
class SyncStatus {
  const SyncStatus({
    this.state = SyncState.idle,
    this.lastSyncAt,
    this.pendingConflictCount = 0,
    this.errorMessage,
  });

  final SyncState state;
  final DateTime? lastSyncAt;
  final int pendingConflictCount;
  final String? errorMessage;

  SyncStatus copyWith({
    SyncState? state,
    DateTime? lastSyncAt,
    int? pendingConflictCount,
    String? errorMessage,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pendingConflictCount:
            pendingConflictCount ?? this.pendingConflictCount,
        errorMessage: errorMessage,
      );
}

/// StateNotifier managing sync status updates.
class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void setSyncing() {
    state = state.copyWith(state: SyncState.syncing);
  }

  void setIdle(DateTime syncedAt) {
    state = state.copyWith(state: SyncState.idle, lastSyncAt: syncedAt);
  }

  void setOffline() {
    state = state.copyWith(state: SyncState.offline);
  }

  void setError(String message) {
    state = state.copyWith(state: SyncState.error, errorMessage: message);
  }

  void setConflict(int count) {
    state = state.copyWith(
      state: SyncState.conflict,
      pendingConflictCount: count,
    );
  }

  /// T113: Set quota-exceeded banner state.
  void setQuotaExceeded() {
    state = state.copyWith(
      state: SyncState.error,
      errorMessage:
          'Cloud storage full — new scores will not sync until storage is freed.',
    );
  }

  /// T114: Set max-retry-exhaustion state.
  void setMaxRetriesExhausted(String details) {
    state = state.copyWith(
      state: SyncState.error,
      errorMessage: 'Sync failed after 10 retries: $details',
    );
  }
}

/// Riverpod provider for [SyncStatusNotifier].
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>(
  (_) => SyncStatusNotifier(),
);
