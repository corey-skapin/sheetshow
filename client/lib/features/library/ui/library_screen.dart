import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/workspace_service.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/core/theme/app_typography.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/models/realbook_model.dart';
import 'package:sheetshow/features/library/repositories/realbook_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/library/services/import_service.dart';
import 'package:sheetshow/features/library/services/search_service.dart';
import 'package:sheetshow/features/library/ui/score_card.dart';
import 'package:sheetshow/features/library/ui/folder_tree.dart';
import 'package:sheetshow/features/library/ui/score_detail_sheet.dart';
import 'package:sheetshow/features/library/ui/realbook_detail_sheet.dart';
import 'package:sheetshow/features/library/ui/score_review_dialog.dart';
import 'package:sheetshow/features/reader/models/reader_args.dart';

// T039: LibraryScreen — reactive grid of scores with import FAB, folder sidebar, search bar.

/// Main library screen showing all scores as a grid with folder navigation.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String? _selectedFolderId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  /// null = idle; non-null = (done, total) progress during batch import.
  (int, int)? _importProgress;
  bool get _isImporting => _importProgress != null;
  CancellationToken? _cancelToken;

  // ─── Multi-select ──────────────────────────────────────────────────────────
  final Set<String> _selectedIds = {};
  final Set<String> _filterTags = {};
  String? _selectedRealbookId;
  bool _sortByPage = false;

  void _toggleSelect(ScoreModel score) {
    setState(() {
      if (_selectedIds.contains(score.id)) {
        _selectedIds.remove(score.id);
      } else {
        _selectedIds.add(score.id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _exitWorkspace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit Workspace'),
        content: const Text(
          'Return to the workspace selection screen? '
          'Your data will be preserved and available when you reopen '
          'this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(workspaceServiceProvider).clearWorkspacePath();
    ref.invalidate(databaseProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchService = ref.watch(searchServiceProvider);
    final scoreRepo = ref.watch(scoreRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          // Search bar
          SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _selectedRealbookId != null
                      ? 'Search by title or page…'
                      : 'Search scores…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: 'Set Lists',
            onPressed: () => context.go('/setlists'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (v) {
              if (v == 'exit_workspace') _exitWorkspace();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'exit_workspace',
                child: Text('Exit Workspace'),
              ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: folders + realbooks
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Expanded(
                  child: FolderTree(
                    selectedFolderId:
                        _selectedRealbookId == null ? _selectedFolderId : null,
                    onFolderSelected: (id) => setState(() {
                      _selectedFolderId = id;
                      _selectedRealbookId = null;
                      _sortByPage = false;
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedIds.clear();
                      _filterTags.clear();
                    }),
                  ),
                ),
                const Divider(height: 1),
                _RealbookSidebar(
                  selectedRealbookId: _selectedRealbookId,
                  onRealbookSelected: (id) => setState(() {
                    _selectedRealbookId = id;
                    _selectedFolderId = null;
                    _searchQuery = '';
                    _searchController.clear();
                    _selectedIds.clear();
                    _filterTags.clear();
                  }),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Score grid
          Expanded(
            child: Column(
              children: [
                if (_selectedIds.isNotEmpty)
                  _SelectionBar(
                    count: _selectedIds.length,
                    onClear: _clearSelection,
                    onEditTags: _bulkEditTags,
                    onDelete: _bulkDelete,
                  ),
                Expanded(
                  child: StreamBuilder<List<ScoreModel>>(
                    stream: _searchQuery.trim().isNotEmpty &&
                            _selectedRealbookId == null
                        ? searchService.searchStream(_searchQuery)
                        : scoreRepo.watchAll(
                            folderId: _selectedFolderId,
                            realbookId: _selectedRealbookId,
                          ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allScores = snapshot.data ?? [];
                      final allTags = {
                        for (final s in allScores) ...s.effectiveTags,
                      }.toList()
                        ..sort();
                      var scores = _filterTags.isEmpty
                          ? allScores
                          : allScores
                              .where((s) => _filterTags
                                  .every((t) => s.effectiveTags.contains(t)))
                              .toList();
                      // When viewing a realbook and searching, also match page numbers.
                      if (_searchQuery.trim().isNotEmpty &&
                          _selectedRealbookId != null) {
                        final q = _searchQuery.trim().toLowerCase();
                        final pageNum = int.tryParse(q);
                        scores = scores.where((s) {
                          if (s.title.toLowerCase().contains(q)) return true;
                          if (pageNum != null && s.bookPage != null) {
                            final bp = s.bookPage!;
                            final bep = s.bookEndPage ?? bp;
                            if (pageNum >= bp && pageNum <= bep) return true;
                          }
                          return false;
                        }).toList();
                      }
                      if (_sortByPage && _selectedRealbookId != null) {
                        scores = [...scores]..sort((a, b) =>
                            (a.startPage ?? 0).compareTo(b.startPage ?? 0));
                      }
                      if (allScores.isEmpty && _selectedIds.isEmpty) {
                        return _EmptyState(onImport: _importFiles);
                      }
                      return Column(
                        children: [
                          if (_selectedRealbookId != null || allTags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  if (_selectedRealbookId != null)
                                    SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(
                                          value: false,
                                          label: Text('A–Z'),
                                          icon: Icon(Icons.sort_by_alpha),
                                        ),
                                        ButtonSegment(
                                          value: true,
                                          label: Text('Page'),
                                          icon:
                                              Icon(Icons.format_list_numbered),
                                        ),
                                      ],
                                      selected: {_sortByPage},
                                      onSelectionChanged: (v) =>
                                          setState(() => _sortByPage = v.first),
                                    ),
                                  if (_selectedRealbookId != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Builder(builder: (context) {
                                      final reviewCount = allScores
                                          .where((s) => s.needsReview)
                                          .length;
                                      return TextButton.icon(
                                        onPressed: () {
                                          final rbTitle = allScores
                                                  .firstOrNull?.realbookTitle ??
                                              '';
                                          _openReviewDialog(
                                            _selectedRealbookId!,
                                            rbTitle,
                                          );
                                        },
                                        icon: Icon(
                                          Icons.rate_review_outlined,
                                          color: reviewCount > 0
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .error
                                              : null,
                                        ),
                                        label: Text(
                                          reviewCount > 0
                                              ? 'Review ($reviewCount)'
                                              : 'Review',
                                        ),
                                      );
                                    }),
                                  ],
                                  if (_selectedRealbookId != null &&
                                      allTags.isNotEmpty)
                                    const SizedBox(width: AppSpacing.md),
                                  if (allTags.isNotEmpty)
                                    Expanded(
                                      child: _TagFilterBar(
                                        tags: allTags,
                                        selectedTags: _filterTags,
                                        onToggle: (tag) => setState(() {
                                          if (_filterTags.contains(tag)) {
                                            _filterTags.remove(tag);
                                          } else {
                                            _filterTags.add(tag);
                                          }
                                        }),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: scores.isEmpty
                                ? const Center(
                                    child: Text('No scores match the filter.'))
                                : _ScoreGrid(
                                    scores: scores,
                                    selectedIds: _selectedIds,
                                    onTap: (score) {
                                      final index = scores.indexOf(score);
                                      context.push(
                                        '/reader/${score.id}',
                                        extra: ReaderArgs(
                                          score: score,
                                          scores: scores,
                                          currentIndex: index,
                                        ),
                                      );
                                    },
                                    onToggleSelect: _toggleSelect,
                                    onContextMenu: (score) => _showContextMenu(
                                      score,
                                      folderId: _selectedFolderId,
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _ImportFab(
        isImporting: _isImporting,
        importProgress: _importProgress,
        onImportFiles: _importFiles,
        onImportFolder: _importFolder,
        onImportRealbook: _importRealbook,
        onCancel: _isImporting ? () => _cancelToken?.cancel() : null,
      ),
    );
  }

  Future<void> _importFiles() async {
    final token = CancellationToken();
    setState(() {
      _importProgress = (0, 1);
      _cancelToken = token;
    });
    try {
      await ref.read(importServiceProvider).importFiles(
            folderId: _selectedFolderId,
            onProgress: (done, total) {
              if (mounted) setState(() => _importProgress = (done, total));
            },
            cancelToken: token,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _importProgress = null;
          _cancelToken = null;
        });
      }
    }
  }

  Future<void> _importFolder() async {
    final token = CancellationToken();
    setState(() {
      _importProgress = (0, 1);
      _cancelToken = token;
    });
    try {
      await ref.read(importServiceProvider).importFolder(
            parentFolderId: _selectedFolderId,
            onProgress: (done, total) {
              if (mounted) setState(() => _importProgress = (done, total));
            },
            cancelToken: token,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _importProgress = null;
          _cancelToken = null;
        });
      }
    }
  }

  Future<void> _importRealbook() async {
    // Ask user for the page offset before importing.
    final pageOne = await showDialog<int>(
      context: context,
      builder: (ctx) => _PageOffsetDialog(),
    );
    if (pageOne == null) return; // cancelled

    final pageOffset = pageOne - 1; // convert "page 1 is PDF page X" to offset

    setState(() {
      _importProgress = (0, 1);
    });
    try {
      final result = await ref.read(importServiceProvider).importRealbook(
            pageOffset: pageOffset,
            onProgress: (done, total) {
              if (mounted) setState(() => _importProgress = (done, total));
            },
          );
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported "${result.title}" — ${result.scoreCount} scores detected',
            ),
          ),
        );
        // Auto-select the new realbook and open review dialog.
        setState(() => _selectedRealbookId = result.id);
        _openReviewDialog(result.id, result.title);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _importProgress = null;
          _cancelToken = null;
        });
      }
    }
  }

  void _openReviewDialog(String realbookId, String realbookTitle) {
    showDialog<void>(
      context: context,
      builder: (_) => ScoreReviewDialog(
        realbookId: realbookId,
        realbookTitle: realbookTitle,
      ),
    );
  }

  void _showContextMenu(ScoreModel score, {String? folderId}) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ScoreDetailSheet(score: score, folderId: folderId),
    );
  }

  Future<void> _bulkEditTags() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BulkTagDialog(scoreIds: _selectedIds.toList()),
    );
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Scores'),
        content: Text(
          'Delete $count score${count == 1 ? '' : 's'}? This cannot be undone.',
        ),
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
      final repo = ref.read(scoreRepositoryProvider);
      for (final id in _selectedIds.toList()) {
        await repo.delete(id);
      }
      _clearSelection();
    }
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({
    required this.scores,
    required this.selectedIds,
    required this.onTap,
    required this.onToggleSelect,
    required this.onContextMenu,
  });

  final List<ScoreModel> scores;
  final Set<String> selectedIds;
  final void Function(ScoreModel) onTap;
  final void Function(ScoreModel) onToggleSelect;
  final void Function(ScoreModel) onContextMenu;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.72,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: scores.length,
      itemBuilder: (ctx, i) {
        final score = scores[i];
        final isSelected = selectedIds.contains(score.id);
        return GestureDetector(
          onLongPress: () => onContextMenu(score),
          onSecondaryTap: () => onContextMenu(score),
          child: ScoreCard(
            score: score,
            isSelected: isSelected,
            tags: score.effectiveTags,
            onTap: () {
              // Ctrl+click, or click while any item is selected → toggle
              if (selectedIds.isNotEmpty ||
                  HardwareKeyboard.instance.isControlPressed) {
                onToggleSelect(score);
              } else {
                onTap(score);
              }
            },
          ),
        );
      },
    );
  }
}

// ─── Tag filter bar ───────────────────────────────────────────────────────────

class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({
    required this.tags,
    required this.selectedTags,
    required this.onToggle,
  });

  final List<String> tags;
  final Set<String> selectedTags;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final tag = tags[i];
          final selected = selectedTags.contains(tag);
          return FilterChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) => onToggle(tag),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

// ─── Selection bar ────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onEditTags,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onEditTags;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear selection',
              onPressed: onClear,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$count selected',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onEditTags,
              icon: const Icon(Icons.label_outline),
              label: const Text('Edit tags'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bulk tag dialog ─────────────────────────────────────────────────────────

class _BulkTagDialog extends ConsumerStatefulWidget {
  const _BulkTagDialog({required this.scoreIds});

  final List<String> scoreIds;

  @override
  ConsumerState<_BulkTagDialog> createState() => _BulkTagDialogState();
}

class _BulkTagDialogState extends ConsumerState<_BulkTagDialog> {
  List<String> _commonTags = [];
  final Set<String> _tagsToRemove = {};
  final List<String> _tagsToAdd = [];
  final _controller = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(scoreRepositoryProvider);
    final allTagSets = await Future.wait(
      widget.scoreIds.map((id) => repo.getTags(id)),
    );
    if (allTagSets.isEmpty) return;
    final common = allTagSets.first.toSet();
    for (final tags in allTagSets.skip(1)) {
      common.retainAll(tags);
    }
    if (mounted) {
      setState(() {
        _commonTags = common.toList()..sort();
        _loading = false;
      });
    }
  }

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty || _tagsToAdd.contains(t) || _commonTags.contains(t)) return;
    setState(() => _tagsToAdd.add(t));
    _controller.clear();
  }

  Future<void> _apply() async {
    final repo = ref.read(scoreRepositoryProvider);
    for (final id in widget.scoreIds) {
      final current = await repo.getTags(id);
      final updated = {
        ...current.where((t) => !_tagsToRemove.contains(t)),
        ..._tagsToAdd,
      }.toList();
      await repo.setTags(id, updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.scoreIds.length;
    return AlertDialog(
      title: Text('Edit tags — $count score${count == 1 ? '' : 's'}'),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_commonTags.isNotEmpty) ...[
                    Text(
                      'Common tags (remove from all):',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: _commonTags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              deleteIcon: _tagsToRemove.contains(tag)
                                  ? const Icon(Icons.undo, size: 14)
                                  : const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() {
                                if (_tagsToRemove.contains(tag)) {
                                  _tagsToRemove.remove(tag);
                                } else {
                                  _tagsToRemove.add(tag);
                                }
                              }),
                              backgroundColor: _tagsToRemove.contains(tag)
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_tagsToAdd.isNotEmpty) ...[
                    Text(
                      'Tags to add to all:',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: _tagsToAdd
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              onDeleted: () =>
                                  setState(() => _tagsToAdd.remove(tag)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Add tag to all…',
                            isDense: true,
                          ),
                          onSubmitted: _addTag,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addTag(_controller.text),
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
          onPressed: _loading ? null : _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Tap "Import" to add sheet music.'),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add),
            label: const Text('Import files'),
          ),
        ],
      ),
    );
  }
}

// ─── Import FAB ───────────────────────────────────────────────────────────────

/// A multi-button FAB column for import actions.
class _ImportFab extends StatelessWidget {
  const _ImportFab({
    required this.isImporting,
    required this.importProgress,
    required this.onImportFiles,
    required this.onImportFolder,
    required this.onImportRealbook,
    required this.onCancel,
  });

  final bool isImporting;
  final (int, int)? importProgress;
  final VoidCallback onImportFiles;
  final VoidCallback onImportFolder;
  final VoidCallback onImportRealbook;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (isImporting) {
      final (done, total) = importProgress ?? (0, 1);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import_cancel',
            tooltip: 'Cancel import (finishes current file)',
            onPressed: onCancel,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            child: const Icon(Icons.close),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'import_progress',
            onPressed: null,
            icon: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: Text(total > 1 ? 'Importing $done/$total…' : 'Importing…'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'import_realbook',
          tooltip: 'Add realbook',
          onPressed: onImportRealbook,
          child: const Icon(Icons.menu_book),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'import_folder',
          tooltip: 'Import folder',
          onPressed: onImportFolder,
          child: const Icon(Icons.folder_open),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'import_files',
          onPressed: onImportFiles,
          icon: const Icon(Icons.add),
          label: const Text('Import files'),
        ),
      ],
    );
  }
}

// ─── Realbook sidebar ─────────────────────────────────────────────────────────

class _RealbookSidebar extends ConsumerWidget {
  const _RealbookSidebar({
    required this.selectedRealbookId,
    required this.onRealbookSelected,
  });

  final String? selectedRealbookId;
  final void Function(String?) onRealbookSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<RealbookModel>>(
      stream: ref.watch(realbookRepositoryProvider).watchAll(),
      builder: (context, snapshot) {
        final realbooks = snapshot.data ?? [];
        if (realbooks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                'Realbooks',
                style: AppTypography.labelSmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...realbooks.map(
              (rb) {
                final isSelected = selectedRealbookId == rb.id;
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.menu_book,
                      size: 20,
                      color:
                          isSelected ? colorScheme.onPrimaryContainer : null),
                  title: Text(
                    rb.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? colorScheme.onPrimaryContainer : null,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  subtitle: Text(
                    '${rb.scoreCount} scores',
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected ? colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert,
                        size: 18,
                        color:
                            isSelected ? colorScheme.onPrimaryContainer : null),
                    tooltip: 'Manage realbook',
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => RealbookDetailSheet(realbook: rb),
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: colorScheme.primaryContainer,
                  onTap: () => onRealbookSelected(
                    isSelected ? null : rb.id,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Dialog asking the user which PDF page corresponds to "page 1" in the
/// realbook. This offset is applied when converting the book's own page
/// numbers (from the index) to PDF page numbers.
class _PageOffsetDialog extends StatefulWidget {
  @override
  State<_PageOffsetDialog> createState() => _PageOffsetDialogState();
}

class _PageOffsetDialogState extends State<_PageOffsetDialog> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Page Offset'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What PDF page number is "page 1" in this realbook? '
            'This accounts for intro/index pages before the scores begin.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'PDF page of "page 1"',
              border: OutlineInputBorder(),
              helperText: 'Default is 1 (no offset)',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Import'),
        ),
      ],
    );
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim()) ?? 1;
    Navigator.pop(context, value.clamp(1, 9999));
  }
}
