import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/services/search_service.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';
import 'package:sheetshow/features/setlists/models/set_list_model.dart';
import 'package:sheetshow/features/setlists/repositories/set_list_repository.dart';
import 'package:sheetshow/features/setlists/ui/performance_mode_screen.dart';

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
  Map<String, ScoreModel> _scoreCache = {};
  int? _dragHoverIndex;
  bool _isDraggingFromSearch = false;
  final Set<String> _adding = {}; // scoreIds currently being added

  @override
  void initState() {
    super.initState();
    _loadSetList();
    _loadAllScores();
  }

  Future<void> _loadAllScores() async {
    final results =
        await ref.read(searchServiceProvider).searchStream('').first;
    if (mounted) {
      setState(() {
        _searchResults = results;
        _scoreCache = {for (final s in results) s.id: s};
      });
    }
  }

  Future<void> _loadSetList() async {
    final sl = await ref
        .read(setListRepositoryProvider)
        .getWithEntries(widget.setListId);
    if (mounted) setState(() => _setList = sl);
  }

  void _startPerformanceFrom(int index) {
    ref.read(performancePositionProvider.notifier).update(
          (map) => {...map, widget.setListId: index},
        );
    context.go('/setlists/${widget.setListId}/performance');
  }

  /// Add [score] via + button: optimistic update + guard against double-tap.
  Future<void> _addScore(ScoreModel score) async {
    if (_adding.contains(score.id)) return;
    final sl = _setList;
    if (sl == null) return;

    // Optimistic: immediately append a temp entry so the UI responds instantly.
    final tempEntry = SetListEntryModel(
      id: '_tmp_${score.id}',
      setListId: widget.setListId,
      scoreId: score.id,
      orderIndex: sl.entries.length,
      addedAt: DateTime.now(),
    );
    setState(() {
      _adding.add(score.id);
      _setList = sl.copyWith(entries: [...sl.entries, tempEntry]);
    });

    try {
      await ref
          .read(setListRepositoryProvider)
          .addEntry(widget.setListId, score.id);
    } finally {
      await _loadSetList();
      if (mounted) setState(() => _adding.remove(score.id));
    }
  }

  /// Add [score] to the set list at [index] (from drag-and-drop).
  Future<void> _insertScoreAt(ScoreModel score, int index) async {
    setState(() => _dragHoverIndex = null);
    final sl = _setList;
    if (sl == null) return;

    // Optimistic: append then show it at the target slot immediately.
    final tempEntry = SetListEntryModel(
      id: '_tmp_${score.id}',
      setListId: widget.setListId,
      scoreId: score.id,
      orderIndex: index,
      addedAt: DateTime.now(),
    );
    final optimistic = List.of(sl.entries);
    final clampedIndex = index.clamp(0, optimistic.length);
    optimistic.insert(clampedIndex, tempEntry);
    setState(() => _setList = sl.copyWith(entries: optimistic));

    await ref
        .read(setListRepositoryProvider)
        .addEntry(widget.setListId, score.id);
    await _loadSetList();
    final updated = _setList;
    if (updated == null || updated.entries.isEmpty) return;
    final entries = List.of(updated.entries);
    final inserted = entries.removeLast();
    final finalIndex = clampedIndex.clamp(0, entries.length);
    entries.insert(finalIndex, inserted);
    setState(() => _setList = updated.copyWith(entries: entries));
    await ref.read(setListRepositoryProvider).reorderEntries(
          widget.setListId,
          entries.map((e) => e.id).toList(),
        );
    await _loadSetList();
  }

  @override
  Widget build(BuildContext context) {
    final sl = _setList;
    if (sl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/setlists')),
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
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    // Insertion indicator shown between/around items while dragging.
    Widget insertionLine() => Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          color: accentColor,
        );

    // Drop zone that shows an insertion line when a score hovers over it.
    Widget dropZone(int insertAt) => DragTarget<ScoreModel>(
          onWillAcceptWithDetails: (_) => true,
          onMove: (_) => setState(() => _dragHoverIndex = insertAt),
          onLeave: (_) => setState(() {
            if (_dragHoverIndex == insertAt) _dragHoverIndex = null;
          }),
          onAcceptWithDetails: (d) => _insertScoreAt(d.data, insertAt),
          builder: (_, candidates, __) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height:
                (_dragHoverIndex == insertAt || candidates.isNotEmpty) ? 16 : 4,
            child: (_dragHoverIndex == insertAt || candidates.isNotEmpty)
                ? Center(child: insertionLine())
                : null,
          ),
        );

    Widget buildItem(int i) {
      final entry = sl.entries[i];
      final score = _scoreCache[entry.scoreId];

      // T062: Handle orphaned entry (score not found in cache).
      if (_scoreCache.isNotEmpty && score == null) {
        return ReorderableDragStartListener(
          key: ValueKey(entry.id),
          index: i,
          child: ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            title: const Text('Score not found — removed from library'),
            subtitle: const Text('Tap × to remove from set list'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await ref.read(setListRepositoryProvider).removeEntry(entry.id);
                await _loadSetList();
              },
            ),
          ),
        );
      }

      return ReorderableDragStartListener(
        key: ValueKey(entry.id),
        index: i,
        child: ListTile(
          leading: Text(
            '${i + 1}',
            style: theme.textTheme.titleMedium,
          ),
          title: Text(score?.title ?? '…'),
          subtitle: Text('${score?.totalPages ?? 0} pages'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Start performance from here',
                onPressed: () => _startPerformanceFrom(i),
              ),
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
        ),
      );
    }

    if (sl.entries.isEmpty) {
      return DragTarget<ScoreModel>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => _insertScoreAt(d.data, 0),
        builder: (_, candidates, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: candidates.isNotEmpty
              ? BoxDecoration(
                  border: Border.all(color: accentColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: const Center(
            child: Text('Search for scores and add them to this set list.'),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
            buildDefaultDragHandles: false,
            itemCount: sl.entries.length,
            onReorder: (oldIndex, newIndex) async {
              final entries = List.of(sl.entries);
              if (newIndex > oldIndex) newIndex--;
              final entry = entries.removeAt(oldIndex);
              entries.insert(newIndex, entry);
              setState(() => _setList = sl.copyWith(entries: entries));
              await ref.read(setListRepositoryProvider).reorderEntries(
                    widget.setListId,
                    entries.map((e) => e.id).toList(),
                  );
              await _loadSetList();
            },
            itemBuilder: (_, i) {
              return Column(
                key: ValueKey(sl.entries[i].id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  dropZone(i),
                  buildItem(i),
                ],
              );
            },
          ),
        ),
        // Append-to-end drop zone — always rendered but only visible while dragging.
        if (_isDraggingFromSearch)
          DragTarget<ScoreModel>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (_) => setState(() => _dragHoverIndex = sl.entries.length),
            onLeave: (_) => setState(() => _dragHoverIndex = null),
            onAcceptWithDetails: (d) =>
                _insertScoreAt(d.data, sl.entries.length),
            builder: (_, candidates, __) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              margin: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: (candidates.isNotEmpty ||
                        _dragHoverIndex == sl.entries.length)
                    ? accentColor.withAlpha(30)
                    : Colors.transparent,
                border: Border.all(
                  color:
                      accentColor.withAlpha(candidates.isNotEmpty ? 200 : 80),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Drop here to add at end',
                  style: TextStyle(color: accentColor),
                ),
              ),
            ),
          ),
      ],
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
              final results =
                  await ref.read(searchServiceProvider).searchStream(q).first;
              if (mounted) setState(() => _searchResults = results);
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (_, i) {
              final score = _searchResults[i];
              return Draggable<ScoreModel>(
                data: score,
                onDragStarted: () =>
                    setState(() => _isDraggingFromSearch = true),
                onDragEnd: (_) => setState(() {
                  _isDraggingFromSearch = false;
                  _dragHoverIndex = null;
                }),
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 220,
                    child: ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(
                        score.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.4,
                  child: ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(score.title),
                    subtitle: Text('${score.totalPages} pages'),
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final inList =
                        _setList?.entries.any((e) => e.scoreId == score.id) ??
                            false;
                    final isPending = _adding.contains(score.id);
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(score.title),
                      subtitle: Text('${score.totalPages} pages'),
                      trailing: inList
                          ? const Icon(Icons.check, color: Colors.green)
                          : isPending
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _addScore(score),
                                ),
                    );
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
