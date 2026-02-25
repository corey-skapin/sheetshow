import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/services/search_service.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';
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
  // ─── State ────────────────────────────────────────────────────────────────

  String _setListName = '';

  /// Authoritative UI entry list. Never replaced while writes are pending.
  List<SetListEntryModel> _entries = [];

  List<ScoreModel> _searchResults = [];
  Map<String, ScoreModel> _scoreCache = {};
  int? _dragHoverIndex;
  bool _isDraggingFromSearch = false;

  /// Number of in-flight DB writes. While > 0, _loadSetList() is a no-op.
  int _pendingWrites = 0;

  // ─── Init ─────────────────────────────────────────────────────────────────

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

  /// Syncs from DB only when no writes are pending (avoids clobbering optimistic state).
  Future<void> _loadSetList() async {
    if (_pendingWrites > 0) return;
    final sl = await ref
        .read(setListRepositoryProvider)
        .getWithEntries(widget.setListId);
    if (!mounted || _pendingWrites > 0) return;
    setState(() {
      _setListName = sl?.name ?? '';
      _entries = sl?.entries ?? [];
    });
  }

  // ─── Mutations (optimistic-first, persist in background) ──────────────────

  void _startPerformanceFrom(int index) {
    ref.read(performancePositionProvider.notifier).update(
          (map) => {...map, widget.setListId: index},
        );
    context.go('/setlists/${widget.setListId}/performance');
  }

  /// Append a score. Generates a real UUID immediately so reorders can
  /// reference it before the DB write completes.
  Future<void> _addScore(ScoreModel score) async {
    if (_entries.any((e) => e.scoreId == score.id)) return;
    final entryId = const Uuid().v4();
    final newEntry = SetListEntryModel(
      id: entryId,
      setListId: widget.setListId,
      scoreId: score.id,
      orderIndex: _entries.length,
      addedAt: DateTime.now(),
    );
    setState(() => _entries = [..._entries, newEntry]);
    _pendingWrites++;
    try {
      await ref
          .read(setListRepositoryProvider)
          .addEntry(widget.setListId, score.id, id: entryId);
    } finally {
      _pendingWrites--;
      if (_pendingWrites == 0 && mounted) await _loadSetList();
    }
  }

  /// Reorder. Operates on `_entries` immediately; persists in background.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final entries = List.of(_entries);
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);
    setState(() => _entries = entries);
    _pendingWrites++;
    try {
      await ref.read(setListRepositoryProvider).reorderEntries(
            widget.setListId,
            entries.map((e) => e.id).toList(),
          );
    } finally {
      _pendingWrites--;
      if (_pendingWrites == 0 && mounted) await _loadSetList();
    }
  }

  /// Remove an entry immediately; persists in background.
  Future<void> _removeEntry(String entryId) async {
    setState(() => _entries = _entries.where((e) => e.id != entryId).toList());
    _pendingWrites++;
    try {
      await ref.read(setListRepositoryProvider).removeEntry(entryId);
    } finally {
      _pendingWrites--;
      if (_pendingWrites == 0 && mounted) await _loadSetList();
    }
  }

  /// Insert a dragged score at [index]; uses real UUID immediately.
  Future<void> _insertScoreAt(ScoreModel score, int index) async {
    if (_entries.any((e) => e.scoreId == score.id)) {
      setState(() => _dragHoverIndex = null);
      return;
    }
    final entryId = const Uuid().v4();
    final clampedIndex = index.clamp(0, _entries.length);
    final newEntry = SetListEntryModel(
      id: entryId,
      setListId: widget.setListId,
      scoreId: score.id,
      orderIndex: clampedIndex,
      addedAt: DateTime.now(),
    );
    final entries = List.of(_entries)..insert(clampedIndex, newEntry);
    setState(() {
      _entries = entries;
      _dragHoverIndex = null;
    });
    _pendingWrites++;
    try {
      await ref
          .read(setListRepositoryProvider)
          .addEntry(widget.setListId, score.id, id: entryId);
      await ref.read(setListRepositoryProvider).reorderEntries(
            widget.setListId,
            entries.map((e) => e.id).toList(),
          );
    } finally {
      _pendingWrites--;
      if (_pendingWrites == 0 && mounted) await _loadSetList();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/setlists')),
        title: Text(_setListName.isEmpty ? '…' : _setListName),
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
          Expanded(flex: 2, child: _buildEntryList()),
          const VerticalDivider(width: 1),
          Expanded(child: _buildSearchPanel()),
        ],
      ),
    );
  }

  // ─── Entry list ──────────────────────────────────────────────────────────

  Widget _buildEntryList() {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    Widget insertionLine() => Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          color: accentColor,
        );

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

    if (_entries.isEmpty) {
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
            itemCount: _entries.length,
            onReorder: _reorder,
            itemBuilder: (_, i) {
              final entry = _entries[i];
              final score = _scoreCache[entry.scoreId];

              // T062: Orphaned entry.
              if (_scoreCache.isNotEmpty && score == null) {
                return ReorderableDragStartListener(
                  key: ValueKey(entry.id),
                  index: i,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      dropZone(i),
                      ListTile(
                        leading: const Icon(Icons.warning_amber,
                            color: Colors.orange),
                        title: const Text(
                            'Score not found — removed from library'),
                        subtitle: const Text('Tap × to remove from set list'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeEntry(entry.id),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ReorderableDragStartListener(
                key: ValueKey(entry.id),
                index: i,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dropZone(i),
                    ListTile(
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
                            onPressed: () => _removeEntry(entry.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_isDraggingFromSearch)
          DragTarget<ScoreModel>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (_) => setState(() => _dragHoverIndex = _entries.length),
            onLeave: (_) => setState(() => _dragHoverIndex = null),
            onAcceptWithDetails: (d) => _insertScoreAt(d.data, _entries.length),
            builder: (_, candidates, __) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              margin: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: (candidates.isNotEmpty ||
                        _dragHoverIndex == _entries.length)
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

  // ─── Search panel ────────────────────────────────────────────────────────

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
              final inList = _entries.any((e) => e.scoreId == score.id);
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
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(score.title),
                  subtitle: Text('${score.totalPages} pages'),
                  trailing: inList
                      ? const Icon(Icons.check, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addScore(score),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
