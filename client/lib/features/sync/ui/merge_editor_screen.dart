import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/sync/models/conflict_info.dart';
import 'package:sheetshow/features/sync/models/sync_status.dart';
import 'package:sheetshow/features/sync/services/sync_service.dart';

// T090: MergeEditorScreen — side-by-side conflict resolution UI.

/// Screen for resolving sync conflicts with side-by-side local vs server view.
class MergeEditorScreen extends ConsumerStatefulWidget {
  const MergeEditorScreen({
    super.key,
    required this.conflicts,
  });

  final List<ConflictInfo> conflicts;

  @override
  ConsumerState<MergeEditorScreen> createState() =>
      _MergeEditorScreenState();
}

class _MergeEditorScreenState extends ConsumerState<MergeEditorScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.conflicts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conflicts')),
        body: const Center(child: Text('No conflicts to resolve.')),
      );
    }

    final conflict = widget.conflicts[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Conflict ${_currentIndex + 1} of ${widget.conflicts.length}'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Conflict type header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conflictTypeLabel(conflict.conflictType),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                        'Entity: ${conflict.entityType.name} (${conflict.entityId})'),
                  ],
                ),
              ),
            ),
          ),
          // Side-by-side comparison
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _ConflictSide(
                    label: 'Your version (local)',
                    payload: conflict.localPayload,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _ConflictSide(
                    label: 'Server version',
                    payload: conflict.serverPayload,
                  ),
                ),
              ],
            ),
          ),
          // Resolution actions
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolve('local'),
                    child: const Text('Take Local'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolve('merge'),
                    child: const Text('Merge Both ✓'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolve('server'),
                    child: const Text('Take Server'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _conflictTypeLabel(ConflictType type) => switch (type) {
        ConflictType.metadataModified => 'Score metadata was changed on both devices',
        ConflictType.annotationModified =>
          'Annotations were changed on both devices',
        ConflictType.deleteVsUpdate =>
          'Score was deleted on one device and modified on another',
        ConflictType.setListModified =>
          'Set list was changed on both devices',
      };

  Future<void> _resolve(String resolution) async {
    // Apply resolution to local DB and enqueue for next sync
    // Full implementation would update entity based on resolution type

    if (_currentIndex < widget.conflicts.length - 1) {
      setState(() => _currentIndex++);
    } else {
      // All resolved
      ref.read(syncStatusProvider.notifier).setIdle(DateTime.now());
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _ConflictSide extends StatelessWidget {
  const _ConflictSide({required this.label, required this.payload});

  final String label;
  final String payload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(label,
              style: Theme.of(context).textTheme.titleSmall),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              payload,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
