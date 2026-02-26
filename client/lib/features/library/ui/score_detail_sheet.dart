import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// T053: ScoreDetailSheet — bottom sheet with tag management and score actions.

/// Bottom sheet for viewing and editing a score's tags, renaming, and deleting.
class ScoreDetailSheet extends ConsumerStatefulWidget {
  const ScoreDetailSheet({super.key, required this.score, this.folderId});

  final ScoreModel score;

  /// If set, shows a "Remove from folder" action in addition to full delete.
  final String? folderId;

  @override
  ConsumerState<ScoreDetailSheet> createState() => _ScoreDetailSheetState();
}

class _ScoreDetailSheetState extends ConsumerState<ScoreDetailSheet> {
  late List<String> _ownTags;
  late List<String> _folderTags;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownTags = [];
    _folderTags = [];
    _loadTags();
  }

  Future<void> _loadTags() async {
    final repo = ref.read(scoreRepositoryProvider);
    final own = await repo.getTags(widget.score.id);
    final effective = await repo.getEffectiveTags(widget.score.id);
    final folder = effective.where((t) => !own.contains(t)).toList();
    if (mounted) {
      setState(() {
        _ownTags = own;
        _folderTags = folder;
      });
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(widget.score.title,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          // Tags section
          Text('Tags', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              ..._ownTags.map(
                (tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 14),
                ),
              ),
              ..._folderTags.map(
                (tag) => Chip(
                  avatar: const Icon(Icons.folder_outlined, size: 14),
                  label: Text(tag),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Add tag input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    hintText: 'Add tag…',
                    isDense: true,
                  ),
                  onSubmitted: _addTag,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add tag',
                onPressed: () => _addTag(_tagController.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Actions
          Row(
            children: [
              TextButton.icon(
                onPressed: _renameScore,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Rename'),
              ),
              const Spacer(),
              if (widget.folderId != null)
                TextButton.icon(
                  onPressed: _removeFromFolder,
                  icon: const Icon(Icons.folder_off_outlined),
                  label: const Text('Remove from folder'),
                ),
              TextButton.icon(
                onPressed: _deleteScore,
                icon: const Icon(Icons.delete_outlined),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty || _ownTags.contains(t)) return;
    setState(() => _ownTags.add(t));
    _tagController.clear();
    _saveTags();
  }

  void _removeTag(String tag) {
    setState(() => _ownTags.remove(tag));
    _saveTags();
  }

  Future<void> _saveTags() async {
    await ref.read(scoreRepositoryProvider).setTags(widget.score.id, _ownTags);
  }

  Future<void> _removeFromFolder() async {
    final folderId = widget.folderId;
    if (folderId == null) return;
    final result = await showDialog<_RemoveChoice>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Score'),
        content: const Text(
          'Remove from this folder only, or delete the score entirely?\n\n'
          'Removing from this folder will also remove any tags this folder '
          'inherited to the score.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_RemoveChoice.folder),
            child: const Text('Remove from folder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_RemoveChoice.all),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete entirely'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result == _RemoveChoice.folder) {
      await ref
          .read(scoreRepositoryProvider)
          .removeFromFolder(widget.score.id, folderId);
    } else {
      await ref.read(scoreRepositoryProvider).delete(widget.score.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _renameScore() async {
    final controller = TextEditingController(text: widget.score.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Score'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await ref.read(scoreRepositoryProvider).update(
            widget.score.copyWith(title: newTitle),
          );
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteScore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Score'),
        content: Text('Delete "${widget.score.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(scoreRepositoryProvider).delete(widget.score.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

enum _RemoveChoice { folder, all }
