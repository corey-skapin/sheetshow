import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/realbook_model.dart';
import 'package:sheetshow/features/library/repositories/realbook_repository.dart';

/// Bottom sheet for managing a realbook — tag editing, rename, re-index, delete.
class RealbookDetailSheet extends ConsumerStatefulWidget {
  const RealbookDetailSheet({super.key, required this.realbook});

  final RealbookModel realbook;

  @override
  ConsumerState<RealbookDetailSheet> createState() =>
      _RealbookDetailSheetState();
}

class _RealbookDetailSheetState extends ConsumerState<RealbookDetailSheet> {
  late List<String> _tags;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = [];
    _loadTags();
  }

  Future<void> _loadTags() async {
    final repo = ref.read(realbookRepositoryProvider);
    final tags = await repo.getTags(widget.realbook.id);
    if (mounted) setState(() => _tags = tags);
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.menu_book),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.realbook.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.realbook.totalPages} pages · '
            '${widget.realbook.scoreCount} scores indexed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Tags section
          Text('Tags (inherited by all scores)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: _tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                    deleteIcon: const Icon(Icons.close, size: 14),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                onPressed: _renameRealbook,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Rename'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _deleteRealbook,
                icon: const Icon(Icons.delete_outlined),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
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
    await ref
        .read(realbookRepositoryProvider)
        .setTags(widget.realbook.id, _tags);
  }

  Future<void> _renameRealbook() async {
    final controller = TextEditingController(text: widget.realbook.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Realbook'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New title'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      await ref
          .read(realbookRepositoryProvider)
          .updateTitle(widget.realbook.id, newTitle);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteRealbook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Realbook'),
        content: Text(
          'This will delete "${widget.realbook.title}" and all '
          '${widget.realbook.scoreCount} indexed scores, including '
          'their annotations, tags, and set list entries.\n\n'
          'The PDF file itself will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(realbookRepositoryProvider).delete(widget.realbook.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
