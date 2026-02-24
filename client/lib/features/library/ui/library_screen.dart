import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/library/services/import_service.dart';
import 'package:sheetshow/features/library/services/search_service.dart';
import 'package:sheetshow/features/library/ui/score_card.dart';
import 'package:sheetshow/features/library/ui/folder_tree.dart';
import 'package:sheetshow/features/library/ui/score_detail_sheet.dart';
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
  bool _isImporting = false;

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
                decoration: const InputDecoration(
                  hintText: 'Search scores…',
                  prefixIcon: Icon(Icons.search),
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
        ],
      ),
      body: Row(
        children: [
          // Folder tree sidebar
          SizedBox(
            width: 220,
            child: FolderTree(
              selectedFolderId: _selectedFolderId,
              onFolderSelected: (id) => setState(() {
                _selectedFolderId = id;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ),
          const VerticalDivider(width: 1),
          // Score grid
          Expanded(
            child: StreamBuilder<List<ScoreModel>>(
              stream: _searchQuery.trim().isNotEmpty
                  ? searchService.searchStream(_searchQuery)
                  : scoreRepo.watchAll(folderId: _selectedFolderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final scores = snapshot.data ?? [];
                if (scores.isEmpty) {
                  return _EmptyState(onImport: _importScore);
                }
                return _ScoreGrid(
                  scores: scores,
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
                  onLongPress: (score) => _showContextMenu(score),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _importScore,
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Import PDF'),
      ),
    );
  }

  Future<void> _importScore() async {
    setState(() => _isImporting = true);
    try {
      await ref.read(importServiceProvider).importPdf();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showContextMenu(ScoreModel score) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ScoreDetailSheet(score: score),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({
    required this.scores,
    required this.onTap,
    required this.onLongPress,
  });

  final List<ScoreModel> scores;
  final void Function(ScoreModel) onTap;
  final void Function(ScoreModel) onLongPress;

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
        return GestureDetector(
          onLongPress: () => onLongPress(score),
          child: ScoreCard(
            score: score,
            onTap: () => onTap(score),
          ),
        );
      },
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
          const Text('Tap "Import PDF" to add sheet music.'),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add),
            label: const Text('Import PDF'),
          ),
        ],
      ),
    );
  }
}
