import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sheetshow/core/services/clock_service.dart';
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

class _SetListBuilderScreenState extends ConsumerState<SetListBuilderScreen>
    with WindowListener {
  // ─── State ────────────────────────────────────────────────────────────────

  String _setListName = '';

  /// Authoritative UI entry list. Never replaced while writes are pending.
  List<SetListEntryModel> _entries = [];

  List<ScoreModel> _searchResults = [];
  final Set<String> _searchFilterTags = {};
  Map<String, ScoreModel> _scoreCache = {};

  List<String> get _allSearchTags => {
        for (final s in _searchResults) ...s.effectiveTags,
      }.toList()
        ..sort();

  List<ScoreModel> get _filteredSearchResults => _searchFilterTags.isEmpty
      ? _searchResults
      : _searchResults
          .where((s) =>
              _searchFilterTags.every((t) => s.effectiveTags.contains(t)))
          .toList();
  int? _dragHoverIndex;
  bool _isDraggingFromSearch = false;

  /// Tracks in-flight DB writes. Notifies the exit dialog reactively.
  final ValueNotifier<int> _pendingWrites = ValueNotifier(0);

  /// Index of the entry whose position number is being edited inline.
  int? _editingIndex;
  final TextEditingController _posController = TextEditingController();
  final FocusNode _posFocusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();

  /// Width of the search panel; dragged by the resize handle.
  double _searchPanelWidth = 320;
  static const double _searchPanelMinWidth = 180;
  static const double _searchPanelMaxWidth = 1200;

  // ─── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadSetList();
    _loadAllScores();
    _posFocusNode.addListener(() {
      if (!_posFocusNode.hasFocus) _commitPositionEdit();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _pendingWrites.dispose();
    _posController.dispose();
    _posFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── WindowListener (app close button) ───────────────────────────────────

  @override
  void onWindowClose() async {
    if (_pendingWrites.value > 0) {
      await _showExitDialog(isAppClose: true);
    } else {
      exit(0);
    }
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
    if (_pendingWrites.value > 0) return;
    final sl = await ref
        .read(setListRepositoryProvider)
        .getWithEntries(widget.setListId);
    if (!mounted || _pendingWrites.value > 0) return;
    setState(() {
      _setListName = sl?.name ?? '';
      _entries = sl?.entries ?? [];
    });
  }

  void _incPending() => _pendingWrites.value++;
  Future<void> _decPending() async {
    _pendingWrites.value--;
    if (_pendingWrites.value == 0 && mounted) await _loadSetList();
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
    final entryId = const Uuid().v4();
    final newEntry = SetListEntryModel(
      id: entryId,
      setListId: widget.setListId,
      scoreId: score.id,
      orderIndex: _entries.length,
      addedAt: ref.read(clockServiceProvider).now(),
    );
    setState(() => _entries = [..._entries, newEntry]);
    _scrollToBottom();
    _incPending();
    try {
      await ref
          .read(setListRepositoryProvider)
          .addEntry(widget.setListId, score.id, id: entryId);
    } finally {
      await _decPending();
    }
  }

  /// Reorder. Operates on `_entries` immediately; persists in background.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final entries = List.of(_entries);
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);
    setState(() => _entries = entries);
    _incPending();
    try {
      await ref.read(setListRepositoryProvider).reorderEntries(
            widget.setListId,
            entries.map((e) => e.id).toList(),
          );
    } finally {
      await _decPending();
    }
  }

  /// Move entry at [fromIndex] to 1-based [toPosition] (from the position editor).
  Future<void> _moveToPosition(int fromIndex, int toPosition) async {
    final targetIndex = (toPosition - 1).clamp(0, _entries.length - 1);
    if (targetIndex == fromIndex) return;
    final entries = List.of(_entries);
    final entry = entries.removeAt(fromIndex);
    entries.insert(targetIndex, entry);
    setState(() => _entries = entries);
    _incPending();
    try {
      await ref.read(setListRepositoryProvider).reorderEntries(
            widget.setListId,
            entries.map((e) => e.id).toList(),
          );
    } finally {
      await _decPending();
    }
  }

  /// Remove an entry immediately; persists in background.
  Future<void> _removeEntry(String entryId) async {
    setState(() => _entries = _entries.where((e) => e.id != entryId).toList());
    _incPending();
    try {
      await ref.read(setListRepositoryProvider).removeEntry(entryId);
    } finally {
      await _decPending();
    }
  }

  /// Insert a dragged score at [index]; uses real UUID immediately.
  Future<void> _insertScoreAt(ScoreModel score, int index) async {
    final entryId = const Uuid().v4();
    final clampedIndex = index.clamp(0, _entries.length);
    final newEntry = SetListEntryModel(
      id: entryId,
      setListId: widget.setListId,
      scoreId: score.id,
      orderIndex: clampedIndex,
      addedAt: ref.read(clockServiceProvider).now(),
    );
    final entries = List.of(_entries)..insert(clampedIndex, newEntry);
    setState(() {
      _entries = entries;
      _dragHoverIndex = null;
    });
    if (clampedIndex >= _entries.length - 1) _scrollToBottom();
    _incPending();
    try {
      await ref
          .read(setListRepositoryProvider)
          .addEntry(widget.setListId, score.id, id: entryId);
      await ref.read(setListRepositoryProvider).reorderEntries(
            widget.setListId,
            entries.map((e) => e.id).toList(),
          );
    } finally {
      await _decPending();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Position editing ─────────────────────────────────────────────────────

  void _startPositionEdit(int index) {
    setState(() {
      _editingIndex = index;
      _posController.text = '${index + 1}';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _posFocusNode.requestFocus();
      _posController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _posController.text.length,
      );
    });
  }

  void _commitPositionEdit() {
    final editing = _editingIndex;
    if (editing == null) return;
    final pos = int.tryParse(_posController.text);
    setState(() => _editingIndex = null);
    if (pos != null && pos >= 1 && pos <= _entries.length) {
      _moveToPosition(editing, pos);
    }
  }

  // ─── Navigation / exit ────────────────────────────────────────────────────

  Future<void> _onBackPressed() async {
    if (_pendingWrites.value > 0) {
      await _showExitDialog(isAppClose: false);
    } else {
      if (mounted) context.go('/setlists');
    }
  }

  Future<void> _showExitDialog({required bool isAppClose}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PendingWritesExitDialog(
        pendingWrites: _pendingWrites,
        onClose: () {
          Navigator.of(context).pop();
          if (isAppClose) {
            exit(0);
          } else {
            context.go('/setlists');
          }
        },
        onForceClose: () {
          if (isAppClose) {
            exit(0);
          } else {
            Navigator.of(context).pop();
            context.go('/setlists');
          }
        },
        isAppClose: isAppClose,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _onBackPressed),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxSearch = (constraints.maxWidth - 200).clamp(
            _searchPanelMinWidth,
            _searchPanelMaxWidth,
          );
          final clampedWidth = _searchPanelWidth.clamp(
            _searchPanelMinWidth,
            maxSearch,
          );
          return Row(
            children: [
              Expanded(child: _buildEntryList()),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => setState(() {
                    _searchPanelWidth = (_searchPanelWidth - d.delta.dx).clamp(
                      _searchPanelMinWidth,
                      maxSearch,
                    );
                  }),
                  child: const SizedBox(
                    width: 6,
                    child: VerticalDivider(width: 6),
                  ),
                ),
              ),
              SizedBox(width: clampedWidth, child: _buildSearchPanel()),
            ],
          );
        },
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
            scrollController: _scrollController,
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
                          tooltip: 'Remove from set list',
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
                      leading: _editingIndex == i
                          ? SizedBox(
                              width: 48,
                              child: TextField(
                                controller: _posController,
                                focusNode: _posFocusNode,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: theme.textTheme.titleMedium,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 4),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _commitPositionEdit(),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _startPositionEdit(i),
                              child: Tooltip(
                                message: 'Tap to change position',
                                child: Text(
                                  '${i + 1}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
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
                            tooltip: 'Remove from set list',
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
    final allTags = _allSearchTags;
    final results = _filteredSearchResults;
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
              final r =
                  await ref.read(searchServiceProvider).searchStream(q).first;
              if (mounted) setState(() => _searchResults = r);
            },
          ),
        ),
        if (allTags.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              itemCount: allTags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final tag = allTags[i];
                final sel = _searchFilterTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _searchFilterTags.remove(tag);
                    } else {
                      _searchFilterTags.add(tag);
                    }
                  }),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, i) {
              final score = results[i];
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
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add to set list',
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

// ─── Exit dialog ─────────────────────────────────────────────────────────────

class _PendingWritesExitDialog extends StatelessWidget {
  const _PendingWritesExitDialog({
    required this.pendingWrites,
    required this.onClose,
    required this.onForceClose,
    required this.isAppClose,
  });

  final ValueNotifier<int> pendingWrites;
  final VoidCallback onClose;
  final VoidCallback onForceClose;
  final bool isAppClose;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saving in progress'),
      content: ValueListenableBuilder<int>(
        valueListenable: pendingWrites,
        builder: (_, pending, __) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pending > 0
                  ? 'There ${pending == 1 ? 'is' : 'are'} $pending pending '
                      '${pending == 1 ? 'change' : 'changes'} being saved. '
                      'Please wait before closing.'
                  : 'All changes saved. You can close safely.',
            ),
            if (pending > 0) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onForceClose,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(isAppClose ? 'Force quit' : 'Discard & leave'),
        ),
        ValueListenableBuilder<int>(
          valueListenable: pendingWrites,
          builder: (_, pending, __) => FilledButton(
            onPressed: pending == 0 ? onClose : null,
            child: Text(isAppClose ? 'Close' : 'Leave'),
          ),
        ),
      ],
    );
  }
}
