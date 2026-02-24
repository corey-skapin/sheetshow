import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/core/theme/app_colors.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/core/theme/app_typography.dart';
import 'package:sheetshow/features/library/models/score_model.dart';

// T038: ScoreCard widget — shows thumbnail, title, sync badge, and tags.

/// Card displayed in the library grid for a single score.
class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.score,
    required this.onTap,
    this.tags = const [],
    this.isSelected = false,
  });

  final ScoreModel score;
  final VoidCallback onTap;
  final List<String> tags;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Score: ${score.title}. ${tags.isEmpty ? '' : 'Tags: ${tags.join(', ')}'}',
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: isSelected ? AppColors.surfaceVariant : AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail
              Expanded(
                child: _buildThumbnail(),
              ),
              // Title + sync badge
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        score.title,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _SyncBadge(state: score.syncState),
                  ],
                ),
              ),
              // Tags row
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: AppSpacing.xs,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: tags
                        .take(3)
                        .map(
                          (t) => Chip(
                            label: Text(
                              t,
                              style: AppTypography.labelSmall,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbPath = score.thumbnailPath;
    if (thumbPath != null) {
      return Image.file(
        File(thumbPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(
            Icons.music_note,
            size: 48,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (state) {
      SyncState.synced => (
          Icons.cloud_done_outlined,
          AppColors.syncSynced,
          'Synced'
        ),
      SyncState.pendingUpload ||
      SyncState.pendingUpdate ||
      SyncState.pendingDelete =>
        (Icons.cloud_upload_outlined, AppColors.syncPending, 'Pending sync'),
      SyncState.conflict => (
          Icons.warning_amber_outlined,
          AppColors.syncConflict,
          'Conflict'
        ),
    };

    return Semantics(
      label: label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}
