import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// T053: ScoreDetailSheet — bottom sheet with tag management and score actions.

/// Bottom sheet for viewing and editing a score's tags, renaming, and deleting.
class ScoreDetailSheet extends ConsumerStatefulWidget {
  const ScoreDetailSheet({super.key, required this.score});

  final ScoreModel score;

  @override
  ConsumerState<ScoreDetailSheet> createState() => _ScoreDetailSheetState();
}

class _ScoreDetailSheetState extends ConsumerState<ScoreDetailSheet> {
  late List<String> _tags;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = [];
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags =
        await ref.read(scoreRepositoryProvider).getTags(widget.score.id);
    if (mounted) setState(() => _tags = tags);
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
              ..._tags.map(
                (tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 14),
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
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() => _tags.add(t));
    _tagController.clear();
    _saveTags();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _saveTags();
  }

  Future<void> _saveTags() async {
    await ref.read(scoreRepositoryProvider).setTags(widget.score.id, _tags);
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
      await ref.read(scoreRepositoryProvider).softDelete(widget.score.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
