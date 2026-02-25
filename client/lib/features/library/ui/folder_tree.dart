import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/core/theme/app_typography.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/folder_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// T049: FolderTree widget — recursive list with collapsible nodes and drag targets.

/// Sidebar widget showing the folder hierarchy with drag-and-drop support.
class FolderTree extends ConsumerStatefulWidget {
  const FolderTree({
    super.key,
    required this.selectedFolderId,
    required this.onFolderSelected,
  });

  final String? selectedFolderId;
  final void Function(String?) onFolderSelected;

  @override
  ConsumerState<FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends ConsumerState<FolderTree> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "All scores" root node — also acts as drop target to unparent folders
        _FolderNode(
          label: 'All Scores',
          icon: Icons.library_music,
          isSelected: widget.selectedFolderId == null,
          isExpanded: false,
          hasChildren: false,
          onTap: () => widget.onFolderSelected(null),
          onAcceptScoreDrop: (_) {},
          onWillAcceptFolder: (_) => true,
          onAcceptFolderDrop: (folder) =>
              ref.read(folderRepositoryProvider).reparent(folder.id, null),
        ),
        const Divider(height: 1),
        // Folder list
        Expanded(
          child: StreamBuilder<List<FolderModel>>(
            stream: ref.watch(folderRepositoryProvider).watchAll(),
            builder: (context, snapshot) {
              final folders = snapshot.data ?? [];
              final roots =
                  folders.where((f) => f.parentFolderId == null).toList();
              return ListView(
                children: roots
                    .map(
                      (f) => _buildFolderTree(f, folders, 0),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // Create folder button
        TextButton.icon(
          onPressed: _createFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('New Folder'),
        ),
      ],
    );
  }

  Widget _buildFolderTree(
    FolderModel folder,
    List<FolderModel> allFolders,
    int depth,
  ) {
    final children =
        allFolders.where((f) => f.parentFolderId == folder.id).toList();

    return Column(
      children: [
        Draggable<FolderModel>(
          data: folder,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder, size: 18),
                  const SizedBox(width: 6),
                  Text(folder.name),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
              opacity: 0.4,
              child: _buildNode(folder, children, allFolders, depth)),
          child: _buildNode(folder, children, allFolders, depth),
        ),
        if (_expanded.contains(folder.id))
          ...children.map((c) => _buildFolderTree(c, allFolders, depth + 1)),
      ],
    );
  }

  Widget _buildNode(
    FolderModel folder,
    List<FolderModel> children,
    List<FolderModel> allFolders,
    int depth,
  ) {
    return _FolderNode(
      folderId: folder.id,
      label: folder.name,
      icon: Icons.folder_outlined,
      depth: depth,
      isSelected: widget.selectedFolderId == folder.id,
      isExpanded: _expanded.contains(folder.id),
      hasChildren: children.isNotEmpty,
      onTap: () => widget.onFolderSelected(folder.id),
      onToggleExpand: () => setState(() {
        if (_expanded.contains(folder.id)) {
          _expanded.remove(folder.id);
        } else {
          _expanded.add(folder.id);
        }
      }),
      onAcceptScoreDrop: (score) => _moveScoreToFolder(score, folder.id),
      onWillAcceptFolder: (dragged) =>
          !_wouldCreateCycle(dragged.id, folder.id, allFolders),
      onAcceptFolderDrop: (dragged) => _moveFolderToFolder(dragged, folder.id),
      onRename: () => _renameFolder(folder),
      onDelete: () => _deleteFolder(folder),
      onNewSubfolder: () => _createSubfolder(folder),
      onEditTags: () => _editFolderTags(folder),
    );
  }

  Future<void> _createFolder() async {
    final name = await _promptFolderName(context, 'New Folder');
    if (name == null || name.isEmpty) return;
    await ref.read(folderRepositoryProvider).create(
          FolderModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _createSubfolder(FolderModel parent) async {
    final name = await _promptFolderName(context, 'New Folder');
    if (name == null || name.isEmpty) return;
    await ref.read(folderRepositoryProvider).create(
          FolderModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            parentFolderId: parent.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    setState(() => _expanded.add(parent.id));
  }

  Future<void> _moveFolderToFolder(
      FolderModel dragged, String targetFolderId) async {
    await ref
        .read(folderRepositoryProvider)
        .reparent(dragged.id, targetFolderId);
    setState(() => _expanded.add(targetFolderId));
  }

  /// Returns true if making [targetId] the parent of [draggedId] would create
  /// a cycle (i.e., [targetId] is [draggedId] or a descendant of it).
  bool _wouldCreateCycle(
    String draggedId,
    String targetId,
    List<FolderModel> allFolders,
  ) {
    if (draggedId == targetId) return true;
    var current = targetId;
    final visited = <String>{};
    while (true) {
      if (visited.contains(current)) return false;
      visited.add(current);
      final folder = allFolders.where((f) => f.id == current).firstOrNull;
      if (folder == null || folder.parentFolderId == null) return false;
      if (folder.parentFolderId == draggedId) return true;
      current = folder.parentFolderId!;
    }
  }

  Future<void> _renameFolder(FolderModel folder) async {
    final name = await _promptFolderName(context, folder.name);
    if (name == null || name.isEmpty) return;
    await ref.read(folderRepositoryProvider).rename(folder.id, name);
  }

  Future<void> _deleteFolder(FolderModel folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Delete "${folder.name}"? Scores inside will move to the root.'),
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
      await ref.read(folderRepositoryProvider).delete(folder.id);
    }
  }

  Future<void> _editFolderTags(FolderModel folder) async {
    final tags = await ref.read(folderRepositoryProvider).getTags(folder.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _FolderTagDialog(
        folder: folder,
        initialTags: tags,
        onSave: (newTags) =>
            ref.read(folderRepositoryProvider).setTags(folder.id, newTags),
      ),
    );
  }

  Future<void> _moveScoreToFolder(ScoreModel score, String folderId) async {
    await ref.read(scoreRepositoryProvider).addToFolder(score.id, folderId);
  }

  Future<String?> _promptFolderName(
      BuildContext context, String initialName) async {
    final controller = TextEditingController(text: initialName);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Folder Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _FolderNode extends StatelessWidget {
  const _FolderNode({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isExpanded,
    required this.hasChildren,
    required this.onTap,
    required this.onAcceptScoreDrop,
    this.folderId,
    this.depth = 0,
    this.onToggleExpand,
    this.onRename,
    this.onDelete,
    this.onNewSubfolder,
    this.onEditTags,
    this.onWillAcceptFolder,
    this.onAcceptFolderDrop,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isExpanded;
  final bool hasChildren;
  final VoidCallback onTap;
  final void Function(ScoreModel) onAcceptScoreDrop;
  final String? folderId;
  final int depth;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onNewSubfolder;
  final VoidCallback? onEditTags;
  final bool Function(FolderModel)? onWillAcceptFolder;
  final void Function(FolderModel)? onAcceptFolderDrop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        if (details.data is FolderModel) {
          return onWillAcceptFolder?.call(details.data as FolderModel) ?? false;
        }
        return details.data is ScoreModel;
      },
      onAcceptWithDetails: (details) {
        if (details.data is FolderModel) {
          onAcceptFolderDrop?.call(details.data as FolderModel);
        } else if (details.data is ScoreModel) {
          onAcceptScoreDrop(details.data as ScoreModel);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Semantics(
          label: 'Folder: $label',
          button: true,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: depth * AppSpacing.md,
              right: AppSpacing.xs,
            ),
            // Expand arrow on left, then folder icon.
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  child: hasChildren
                      ? GestureDetector(
                          onTap: onToggleExpand,
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 16,
                          ),
                        )
                      : null,
                ),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            title: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            tileColor: isHovered
                ? colorScheme.primary.withOpacity(0.1)
                : isSelected
                    ? colorScheme.surfaceContainerHighest
                    : null,
            trailing: (onRename != null ||
                    onDelete != null ||
                    onNewSubfolder != null ||
                    onEditTags != null)
                ? PopupMenuButton<String>(
                    iconSize: 16,
                    onSelected: (v) {
                      if (v == 'rename') onRename?.call();
                      if (v == 'delete') onDelete?.call();
                      if (v == 'subfolder') onNewSubfolder?.call();
                      if (v == 'tags') onEditTags?.call();
                    },
                    itemBuilder: (_) => [
                      if (onNewSubfolder != null)
                        const PopupMenuItem(
                            value: 'subfolder', child: Text('New subfolder')),
                      if (onEditTags != null)
                        const PopupMenuItem(
                            value: 'tags', child: Text('Edit tags')),
                      if (onRename != null)
                        const PopupMenuItem(
                            value: 'rename', child: Text('Rename')),
                      if (onDelete != null)
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                    ],
                  )
                : null,
            onTap: onTap,
          ),
        );
      },
    );
  }
}

// ─── Folder tag dialog ────────────────────────────────────────────────────────

class _FolderTagDialog extends StatefulWidget {
  const _FolderTagDialog({
    required this.folder,
    required this.initialTags,
    required this.onSave,
  });

  final FolderModel folder;
  final List<String> initialTags;
  final Future<void> Function(List<String>) onSave;

  @override
  State<_FolderTagDialog> createState() => _FolderTagDialogState();
}

class _FolderTagDialogState extends State<_FolderTagDialog> {
  late List<String> _tags;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() => _tags.add(t));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tags for "${widget.folder.name}"'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These tags are applied to all scores in this folder.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _tags
                  .map((t) => Chip(
                        label: Text(t),
                        onDeleted: () => setState(() => _tags.remove(t)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: _tags.isEmpty,
                    decoration: const InputDecoration(
                        hintText: 'Add tag…', isDense: true),
                    onSubmitted: _add,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _add(_controller.text),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.onSave(_tags);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
