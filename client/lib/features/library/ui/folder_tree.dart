import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/core/theme/app_colors.dart';
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
        // "All scores" root node
        _FolderNode(
          label: 'All Scores',
          icon: Icons.library_music,
          isSelected: widget.selectedFolderId == null,
          isExpanded: false,
          hasChildren: false,
          onTap: () => widget.onFolderSelected(null),
          onAcceptDrop: (_) {},
        ),
        const Divider(height: 1),
        // Folder list
        Expanded(
          child: StreamBuilder<List<FolderModel>>(
            stream: ref.watch(folderRepositoryProvider).watchAll(),
            builder: (context, snapshot) {
              final folders = snapshot.data ?? [];
              final roots = folders
                  .where((f) => f.parentFolderId == null && !f.isDeleted)
                  .toList();
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
    final children = allFolders
        .where((f) => f.parentFolderId == folder.id && !f.isDeleted)
        .toList();

    return Column(
      children: [
        _FolderNode(
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
          onAcceptDrop: (score) => _moveScoreToFolder(score, folder.id),
          onRename: () => _renameFolder(folder),
          onDelete: () => _deleteFolder(folder),
        ),
        if (_expanded.contains(folder.id))
          ...children.map((c) => _buildFolderTree(c, allFolders, depth + 1)),
      ],
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
            syncState: SyncState.pendingUpload,
          ),
        );
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
      await ref.read(folderRepositoryProvider).softDelete(folder.id);
    }
  }

  Future<void> _moveScoreToFolder(ScoreModel score, String folderId) async {
    await ref
        .read(scoreRepositoryProvider)
        .update(score.copyWith(folderId: folderId));
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
    required this.onAcceptDrop,
    this.depth = 0,
    this.onToggleExpand,
    this.onRename,
    this.onDelete,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isExpanded;
  final bool hasChildren;
  final VoidCallback onTap;
  final void Function(ScoreModel) onAcceptDrop;
  final int depth;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ScoreModel>(
      onAcceptWithDetails: (details) => onAcceptDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Semantics(
          label: 'Folder: $label',
          button: true,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: AppSpacing.sm + depth * AppSpacing.md,
              right: AppSpacing.xs,
            ),
            leading: Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            title: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
            tileColor: isHovered
                ? AppColors.primaryVariant.withOpacity(0.1)
                : isSelected
                    ? AppColors.surfaceVariant
                    : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRename != null || onDelete != null)
                  PopupMenuButton<String>(
                    iconSize: 16,
                    onSelected: (v) {
                      if (v == 'rename') onRename?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onRename != null)
                        const PopupMenuItem(
                            value: 'rename', child: Text('Rename')),
                      if (onDelete != null)
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                    ],
                  ),
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                    ),
                  ),
              ],
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}

