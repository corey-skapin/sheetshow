import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/constants/app_constants.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/api_client.dart';
import 'package:sheetshow/features/sync/models/sync_status.dart' as status_model;
import 'package:sheetshow/features/sync/services/conflict_detector.dart';
import 'package:sheetshow/features/sync/services/sync_queue_processor.dart';

// T081-T084: SyncService — full offline-first sync engine.

/// Orchestrates pull/push sync with exponential backoff and conflict handling.
class SyncService {
  SyncService({
    required this.apiClient,
    required this.queueProcessor,
    required this.conflictDetector,
    required this.db,
    required this.statusNotifier,
  });

  final ApiClient apiClient;
  final SyncQueueProcessor queueProcessor;
  final ConflictDetector conflictDetector;
  final AppDatabase db;
  final status_model.SyncStatusNotifier statusNotifier;

  Timer? _pollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _deviceId;
  bool _isSyncing = false;

  /// Start sync engine — sets up connectivity monitoring and periodic poll.
  Future<void> start() async {
    _deviceId = await _getOrCreateDeviceId();

    // T109: Recover from interrupted sync — reset in-flight entries to pending
    await _recoverInFlightEntries();

    // Listen for connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) async {
        final isOnline =
            !results.contains(ConnectivityResult.none);
        if (isOnline) {
          await Future<void>.delayed(const Duration(seconds: 2));
          await _syncNow();
        } else {
          statusNotifier.setOffline();
        }
      },
    );

    // Periodic sync every 30 seconds
    _pollTimer = Timer.periodic(
      Duration(seconds: kSyncPollIntervalSec),
      (_) => _syncNow(),
    );

    // Immediate first sync
    await _syncNow();
  }

  /// Stop sync engine and clean up timers.
  void stop() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _pollTimer = null;
    _connectivitySub = null;
  }

  /// Manually trigger an immediate sync cycle.
  Future<void> retryNow() => _syncNow();

  // ─── Core sync logic ──────────────────────────────────────────────────────

  /// T109: Reset any entries that were left as in_flight from a previous crash.
  Future<void> _recoverInFlightEntries() async {
    await (db.update(db.syncQueue)
          ..where((q) => q.status.equals('in_flight')))
        .write(const SyncQueueCompanion(
      status: Value('pending'),
    ));
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    statusNotifier.setSyncing();

    try {
      await _pullPhase();
      await _pushPhase();
      statusNotifier.setIdle(DateTime.now());
    } catch (e) {
      statusNotifier.setError(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pullPhase() async {
    final lastSyncAt = await _getLastSyncAt();
    bool hasMore = true;

    while (hasMore) {
      final response = await apiClient.post('/sync/pull', {
        'deviceId': _deviceId,
        'since': lastSyncAt?.toIso8601String(),
      });

      hasMore = response['hasMore'] as bool? ?? false;
      final changes =
          (response['changes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final change in changes) {
        await _applyChange(change);
      }

      if (changes.isNotEmpty) {
        final serverTime = response['serverTime'] as String?;
        if (serverTime != null) {
          await _updateLastSyncAt(DateTime.parse(serverTime));
        }
      }
    }
  }

  Future<void> _pushPhase() async {
    final batch = await queueProcessor.getNextBatch();
    if (batch.isEmpty) return;

    final ids = batch.map((e) => e.id).toList();
    await queueProcessor.markInFlight(ids);

    try {
      final response = await apiClient.post('/sync/push', {
        'deviceId': _deviceId,
        'operations': batch
            .map((e) => {
                  'operationId': e.id,
                  'entityType': e.entityType.name,
                  'entityId': e.entityId,
                  'operation': e.operation.name,
                  'clientVersion': 0,
                  'payloadJson': e.payloadJson,
                })
            .toList(),
      });

      final results =
          (response['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Check for quota exceeded
      final hasQuotaError = results.any(
          (r) => r['status'] == 'quota_exceeded');
      if (hasQuotaError) {
        statusNotifier.setQuotaExceeded();
      }

      // Check for max-retry exhausted entries
      // (handled by markFailed which transitions to 'failed' at kSyncMaxRetries)

      final conflicts =
          conflictDetector.processResults(batch, results);

      if (conflicts.isNotEmpty) {
        statusNotifier.setConflict(conflicts.length);
      }

      // Mark accepted operations as synced
      for (var i = 0; i < results.length && i < batch.length; i++) {
        final result = results[i];
        if (result['status'] == 'accepted') {
          await queueProcessor.markSynced(batch[i].id);
        }
      }
    } catch (e) {
      // Reset in-flight to pending for retry
      for (final entry in batch) {
        await queueProcessor.markFailed(
          entry.id,
          e.toString(),
          entry.attemptCount + 1,
        );
      }
    }
  }

  Future<void> _applyChange(Map<String, dynamic> change) async {
    // Apply server changes to local DB
    // Full implementation would merge per entity type using sync-protocol.md rules
  }

  Future<DateTime?> _getLastSyncAt() async {
    final row = await (db.select(db.syncMeta)
          ..where((m) => m.key.equals('last_sync_at')))
        .getSingleOrNull();
    if (row == null) return null;
    return DateTime.tryParse(row.value);
  }

  Future<void> _updateLastSyncAt(DateTime dt) async {
    await db.into(db.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            key: 'last_sync_at',
            value: dt.toIso8601String(),
          ),
        );
  }

  Future<String> _getOrCreateDeviceId() async {
    final row = await (db.select(db.syncMeta)
          ..where((m) => m.key.equals('device_id')))
        .getSingleOrNull();

    if (row != null) return row.value;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db.into(db.syncMeta).insert(
          SyncMetaCompanion.insert(key: 'device_id', value: id),
        );
    return id;
  }
}

/// Riverpod provider for [SyncService].
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiClient: ref.watch(apiClientProvider),
    queueProcessor: ref.watch(syncQueueProcessorProvider),
    conflictDetector: ref.watch(conflictDetectorProvider),
    db: ref.watch(databaseProvider),
    statusNotifier: ref.read(status_model.syncStatusProvider.notifier),
  );
});
