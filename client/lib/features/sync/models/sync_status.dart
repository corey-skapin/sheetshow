import 'package:flutter_riverpod/flutter_riverpod.dart';

// T078: SyncStatus — exposes sync state to the UI via StateNotifier.

/// Current state of the sync engine (UI-facing; distinct from entity SyncState in core/models/enums.dart).
enum SyncUiState {
  idle,
  syncing,
  conflict,
  offline,
  error,
}

/// Status model for the sync UI indicator.
class SyncStatus {
  const SyncStatus({
    this.state = SyncUiState.idle,
    this.lastSyncAt,
    this.pendingConflictCount = 0,
    this.errorMessage,
  });

  final SyncUiState state;
  final DateTime? lastSyncAt;
  final int pendingConflictCount;
  final String? errorMessage;

  SyncStatus copyWith({
    SyncUiState? state,
    DateTime? lastSyncAt,
    int? pendingConflictCount,
    String? errorMessage,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pendingConflictCount: pendingConflictCount ?? this.pendingConflictCount,
        errorMessage: errorMessage,
      );
}

/// StateNotifier managing sync status updates.
class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void setSyncing() {
    state = state.copyWith(state: SyncUiState.syncing);
  }

  void setIdle(DateTime syncedAt) {
    state = state.copyWith(state: SyncUiState.idle, lastSyncAt: syncedAt);
  }

  void setOffline() {
    state = state.copyWith(state: SyncUiState.offline);
  }

  void setError(String message) {
    state = state.copyWith(state: SyncUiState.error, errorMessage: message);
  }

  void setConflict(int count) {
    state = state.copyWith(
      state: SyncUiState.conflict,
      pendingConflictCount: count,
    );
  }

  /// T113: Set quota-exceeded banner state.
  void setQuotaExceeded() {
    state = state.copyWith(
      state: SyncUiState.error,
      errorMessage:
          'Cloud storage full — new scores will not sync until storage is freed.',
    );
  }

  /// T114: Set max-retry-exhaustion state.
  void setMaxRetriesExhausted(String details) {
    state = state.copyWith(
      state: SyncUiState.error,
      errorMessage: 'Sync failed after 10 retries: $details',
    );
  }
}

/// Riverpod provider for [SyncStatusNotifier].
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>(
  (_) => SyncStatusNotifier(),
);
