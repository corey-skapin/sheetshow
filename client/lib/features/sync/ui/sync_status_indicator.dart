import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/sync_status.dart';
import '../services/sync_service.dart';

// T089: SyncStatusIndicator — app bar widget showing current sync state.

/// Compact sync status indicator for the app bar.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    return GestureDetector(
      onTap: () => _handleTap(context, ref, status),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _buildContent(context, status),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SyncStatus status) {
    switch (status.state) {
      case SyncState.idle:
        final lastSync = status.lastSyncAt;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done_outlined,
                size: 16, color: AppColors.syncSynced),
            const SizedBox(width: 4),
            Text(
              lastSync != null ? 'Synced' : 'Ready',
              style: const TextStyle(fontSize: 12, color: AppColors.syncSynced),
            ),
          ],
        );

      case SyncState.syncing:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 4),
            Text('Syncing…', style: TextStyle(fontSize: 12)),
          ],
        );

      case SyncState.conflict:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_outlined,
                size: 16, color: AppColors.syncConflict),
            const SizedBox(width: 4),
            Text(
              '${status.pendingConflictCount} conflict${status.pendingConflictCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.syncConflict),
            ),
          ],
        );

      case SyncState.offline:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 16, color: AppColors.syncOffline),
            SizedBox(width: 4),
            Text('Offline',
                style: TextStyle(fontSize: 12, color: AppColors.syncOffline)),
          ],
        );

      case SyncState.error:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 16, color: AppColors.error),
            SizedBox(width: 4),
            Text('Sync failed',
                style: TextStyle(fontSize: 12, color: AppColors.error)),
          ],
        );
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref, SyncStatus status) {
    if (status.state == SyncState.error) {
      ref.read(syncServiceProvider).retryNow();
    }
  }
}
