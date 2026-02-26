import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/core/theme/app_colors.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/reader/models/tool_settings.dart';
import 'package:sheetshow/features/reader/services/annotation_service.dart';
import 'package:sheetshow/features/reader/ui/annotation_overlay.dart';

// T074: AnnotationToolbar — tool toggle buttons, colour picker, stroke width slider, undo, clear.

/// Bottom toolbar for annotation mode controls.
class AnnotationToolbar extends ConsumerWidget {
  const AnnotationToolbar({
    super.key,
    required this.scoreId,
    required this.pageNumber,
  });

  final String scoreId;
  final int pageNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(toolSettingsProvider);
    final notifier = ref.read(toolSettingsProvider.notifier);

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Pen
          _ToolButton(
            icon: Icons.edit,
            label: 'Pen',
            isActive: settings.activeTool == AnnotationTool.pen,
            onTap: () => notifier.state =
                ToolSettings.pen.copyWith(color: settings.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Highlighter
          _ToolButton(
            icon: Icons.highlight,
            label: 'Highlighter',
            isActive: settings.activeTool == AnnotationTool.highlighter,
            onTap: () => notifier.state = ToolSettings.highlighter,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Eraser
          _ToolButton(
            icon: Icons.auto_fix_high,
            label: 'Eraser',
            isActive: settings.activeTool == AnnotationTool.eraser,
            onTap: () => notifier.state = ToolSettings.eraser,
          ),
          const SizedBox(width: AppSpacing.md),
          // Colour swatch
          if (settings.activeTool != AnnotationTool.eraser)
            GestureDetector(
              onTap: () => _pickColor(context, ref, settings),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: settings.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          // Stroke width slider
          Expanded(
            child: Semantics(
              label: 'Stroke width',
              child: Slider(
                value: settings.strokeWidth,
                min: 1,
                max: 24,
                onChanged: (v) =>
                    notifier.state = settings.copyWith(strokeWidth: v),
                activeColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Undo
          Semantics(
            label: 'Undo last stroke',
            child: IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              tooltip: 'Undo last stroke',
              onPressed: () => ref
                  .read(annotationServiceProvider(
                    (scoreId: scoreId, pageNumber: pageNumber),
                  ).notifier)
                  .undoLastStroke(),
            ),
          ),
          // Clear all
          Semantics(
            label: 'Clear all annotations',
            child: IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Clear all annotations',
              onPressed: () => _confirmClearAll(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    ToolSettings settings,
  ) async {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Colour'),
        content: Wrap(
          spacing: AppSpacing.sm,
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    ref.read(toolSettingsProvider.notifier).state =
                        settings.copyWith(color: c);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Annotations'),
        content: const Text(
            'Remove all ink strokes from this page? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(annotationServiceProvider(
            (scoreId: scoreId, pageNumber: pageNumber),
          ).notifier)
          .clearAll();
    }
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label tool${isActive ? ' (active)' : ''}',
      button: true,
      child: Tooltip(
        message: '$label tool',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
