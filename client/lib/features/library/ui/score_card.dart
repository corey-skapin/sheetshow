import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/core/theme/app_typography.dart';
import 'package:sheetshow/features/library/models/score_model.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Score: ${score.title}. ${tags.isEmpty ? '' : 'Tags: ${tags.join(', ')}'}',
      button: true,
      child: Stack(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            color:
                isSelected ? colorScheme.primaryContainer : colorScheme.surface,
            shape: isSelected
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.primary, width: 2),
                  )
                : null,
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thumbnail
                  Expanded(
                    child: _buildThumbnail(colorScheme),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (score.needsReview)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.xs),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: colorScheme.error,
                                ),
                              )
                            else if (score.isRealbookExcerpt)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.xs),
                                child: Icon(
                                  Icons.menu_book,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
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
                          ],
                        ),
                        if (score.realbookTitle != null)
                          Text(
                            score.realbookTitle!,
                            style: AppTypography.labelSmall.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (score.isRealbookExcerpt && score.bookPage != null)
                          Text(
                            score.bookPage == score.bookEndPage ||
                                    score.bookEndPage == null
                                ? 'p. ${score.bookPage}'
                                : 'pp. ${score.bookPage}–${score.bookEndPage}',
                            style: AppTypography.labelSmall.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
          if (isSelected)
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.primary,
                child:
                    Icon(Icons.check, size: 16, color: colorScheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme) {
    final thumbPath = score.thumbnailPath;
    if (thumbPath != null) {
      return Image.file(
        File(thumbPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(colorScheme),
      );
    }
    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme colorScheme) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.music_note,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
