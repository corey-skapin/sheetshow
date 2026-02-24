import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/library/services/search_service.dart';
import 'package:sheetshow/features/setlists/models/set_list_model.dart';
import 'package:sheetshow/features/setlists/repositories/set_list_repository.dart';

// T061: SetListBuilderScreen — reorderable set list with inline search.

class SetListBuilderScreen extends ConsumerStatefulWidget {
  const SetListBuilderScreen({super.key, required this.setListId});

  final String setListId;

  @override
  ConsumerState<SetListBuilderScreen> createState() =>
      _SetListBuilderScreenState();
}

class _SetListBuilderScreenState extends ConsumerState<SetListBuilderScreen> {
  SetListModel? _setList;
  List<ScoreModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadSetList();
  }

  Future<void> _loadSetList() async {
    final sl = await ref
        .read(setListRepositoryProvider)
        .getWithEntries(widget.setListId);
    if (mounted) setState(() => _setList = sl);
  }

  @override
  Widget build(BuildContext context) {
    final sl = _setList;
    if (sl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sl.name),
        actions: [
          ElevatedButton.icon(
            onPressed: () =>
                context.go('/setlists/${widget.setListId}/performance'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Performance'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Row(
        children: [
          // Reorderable list of entries
          Expanded(
            flex: 2,
            child: _buildEntryList(sl),
          ),
          const VerticalDivider(width: 1),
          // Score search panel
          Expanded(
            child: _buildSearchPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(SetListModel sl) {
    if (sl.entries.isEmpty) {
      return const Center(
        child: Text('Search for scores and add them to this set list.'),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: sl.entries.length,
      onReorder: (oldIndex, newIndex) async {
        final entries = List.of(sl.entries);
        if (newIndex > oldIndex) newIndex--;
        final entry = entries.removeAt(oldIndex);
        entries.insert(newIndex, entry);
        await ref.read(setListRepositoryProvider).reorderEntries(
              widget.setListId,
              entries.map((e) => e.id).toList(),
            );
        await _loadSetList();
      },
      itemBuilder: (_, i) {
        final entry = sl.entries[i];
        return FutureBuilder<ScoreModel?>(
          key: ValueKey(entry.id),
          future: ref.read(scoreRepositoryProvider).getById(entry.scoreId),
          builder: (_, snapshot) {
            final score = snapshot.data;
            // T062: Handle orphaned entry (score not found)
            if (snapshot.connectionState == ConnectionState.done &&
                score == null) {
              return ListTile(
                key: ValueKey(entry.id),
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: const Text('Score not found — removed from library'),
                subtitle: const Text('Tap × to remove from set list'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await ref
                        .read(setListRepositoryProvider)
                        .removeEntry(entry.id);
                    await _loadSetList();
                  },
                ),
              );
            }

            return ListTile(
              key: ValueKey(entry.id),
              leading: Text(
                '${i + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              title: Text(score?.title ?? '…'),
              subtitle: Text('${score?.totalPages ?? 0} pages'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drag_handle),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await ref
                          .read(setListRepositoryProvider)
                          .removeEntry(entry.id);
                      await _loadSetList();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search scores to add…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (q) async {
              if (q.isEmpty) {
                setState(() => _searchResults = []);
              } else {
                final results =
                    await ref.read(searchServiceProvider).searchStream(q).first;
                if (mounted) setState(() => _searchResults = results);
              }
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (_, i) {
              final score = _searchResults[i];
              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(score.title),
                subtitle: Text('${score.totalPages} pages'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    await ref.read(setListRepositoryProvider).addEntry(
                          widget.setListId,
                          score.id,
                        );
                    await _loadSetList();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
