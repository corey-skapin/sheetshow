import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/reader/ui/reader_screen.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';
import 'package:sheetshow/features/setlists/repositories/set_list_repository.dart';

// T063: PerformanceModeScreen — fullscreen set list player with prev/next controls.

/// In-memory position store: maps setListId → last viewed score index.
/// Can be written externally to start performance from a specific position.
final performancePositionProvider =
    StateProvider<Map<String, int>>((ref) => {});

class PerformanceModeScreen extends ConsumerStatefulWidget {
  const PerformanceModeScreen({super.key, required this.setListId});

  final String setListId;

  @override
  ConsumerState<PerformanceModeScreen> createState() =>
      _PerformanceModeScreenState();
}

class _PerformanceModeScreenState extends ConsumerState<PerformanceModeScreen> {
  List<String> _scoreIds = [];
  List<SetListEntryModel> _entries = [];
  final Map<String, String> _scoreTitles = {};
  int _currentIndex = 0;
  ScoreModel? _currentScore;
  bool _overlayVisible = true;
  bool _sidebarVisible = false;
  Timer? _hideOverlayTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSetList();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideOverlayTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSetList() async {
    final sl = await ref
        .read(setListRepositoryProvider)
        .getWithEntries(widget.setListId);
    if (sl == null || !mounted) return;

    final savedIndex =
        ref.read(performancePositionProvider)[widget.setListId] ?? 0;

    final entries = sl.entries;
    final scoreIds = entries.map((e) => e.scoreId).toList();

    // Pre-load titles for the sidebar.
    final scoreRepo = ref.read(scoreRepositoryProvider);
    final titles = <String, String>{};
    for (final id in scoreIds) {
      final score = await scoreRepo.getById(id);
      if (score != null) titles[id] = score.title;
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _scoreIds = scoreIds;
      _scoreTitles
        ..clear()
        ..addAll(titles);
      _currentIndex =
          savedIndex.clamp(0, entries.isEmpty ? 0 : entries.length - 1);
    });
    await _loadCurrentScore();
  }

  Future<void> _loadCurrentScore() async {
    if (_scoreIds.isEmpty) return;
    final score = await ref
        .read(scoreRepositoryProvider)
        .getById(_scoreIds[_currentIndex]);
    if (mounted) setState(() => _currentScore = score);
  }

  void _savePosition() {
    ref.read(performancePositionProvider.notifier).update(
          (map) => {...map, widget.setListId: _currentIndex},
        );
  }

  void _startHideTimer() {
    _hideOverlayTimer?.cancel();
    _hideOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  void _showOverlay() {
    setState(() => _overlayVisible = true);
    _startHideTimer();
  }

  Future<void> _navigate(int delta) async {
    final next = _currentIndex + delta;
    if (next < 0 || next >= _scoreIds.length) return;
    setState(() {
      _currentIndex = next;
      _currentScore = null;
    });
    _savePosition();
    await _loadCurrentScore();
    _showOverlay();
  }

  Future<void> _jumpTo(int index) async {
    if (index < 0 || index >= _scoreIds.length || index == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = index;
      _currentScore = null;
    });
    _savePosition();
    await _loadCurrentScore();
    _showOverlay();
  }

  void _toggleSidebar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
    if (_sidebarVisible) {
      _hideOverlayTimer?.cancel();
    } else {
      _startHideTimer();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _navigate(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _navigate(-1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final score = _currentScore;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // Main viewer area
            Expanded(
              child: GestureDetector(
                onTap: _showOverlay,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v < -200) {
                    _navigate(1); // swipe left → next
                  } else if (v > 200) {
                    _navigate(-1); // swipe right → previous
                  }
                },
                child: Stack(
                  children: [
                    // PDF viewer
                    if (score != null)
                      ReaderScreen(
                        key: ValueKey(score.id),
                        scoreId: score.id,
                        score: score,
                      )
                    else
                      const Center(child: CircularProgressIndicator()),

                    // Left edge tap zone → previous
                    if (_currentIndex > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 60,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _navigate(-1),
                          child: const MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),

                    // Right edge tap zone → next
                    if (_currentIndex < _scoreIds.length - 1)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 60,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _navigate(1),
                          child: const MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),

                    // Persistent back button (always visible, top-left)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                          onPressed: () => context
                              .go('/setlists/${widget.setListId}/builder'),
                        ),
                      ),
                    ),

                    // Sidebar toggle button (always visible, top-right)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        child: IconButton(
                          icon: Icon(
                            _sidebarVisible
                                ? Icons.playlist_remove
                                : Icons.playlist_play,
                            color: Colors.white,
                          ),
                          tooltip: _sidebarVisible
                              ? 'Hide set list'
                              : 'Show set list',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                          onPressed: _toggleSidebar,
                        ),
                      ),
                    ),

                    // Performance overlay (auto-hides)
                    if (_overlayVisible)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _PerformanceOverlay(
                          title: score?.title ?? '…',
                          currentIndex: _currentIndex,
                          totalCount: _scoreIds.length,
                          onPrevious: () => _navigate(-1),
                          onNext: () => _navigate(1),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Setlist sidebar
            if (_sidebarVisible)
              _SetListSidebar(
                entries: _entries,
                scoreTitles: _scoreTitles,
                currentIndex: _currentIndex,
                onJumpTo: _jumpTo,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Setlist sidebar ──────────────────────────────────────────────────────────

class _SetListSidebar extends StatefulWidget {
  const _SetListSidebar({
    required this.entries,
    required this.scoreTitles,
    required this.currentIndex,
    required this.onJumpTo,
  });

  final List<SetListEntryModel> entries;
  final Map<String, String> scoreTitles;
  final int currentIndex;
  final ValueChanged<int> onJumpTo;

  @override
  State<_SetListSidebar> createState() => _SetListSidebarState();
}

class _SetListSidebarState extends State<_SetListSidebar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(_SetListSidebar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _scrollToCurrent();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final target = widget.currentIndex * itemHeight;
    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Set List',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.entries.length,
              itemExtent: 56.0,
              itemBuilder: (context, i) {
                final entry = widget.entries[i];
                final isCurrent = i == widget.currentIndex;
                final title =
                    widget.scoreTitles[entry.scoreId] ?? 'Unknown score';
                return Material(
                  color: isCurrent
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onJumpTo(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(
                                color:
                                    isCurrent ? Colors.white : Colors.white54,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.play_arrow,
                                  color: Colors.white, size: 18),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color:
                                    isCurrent ? Colors.white : Colors.white70,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceOverlay extends StatelessWidget {
  const _PerformanceOverlay({
    required this.title,
    required this.currentIndex,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${currentIndex + 1} / $totalCount',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            tooltip: 'Previous score',
            onPressed: currentIndex > 0 ? onPrevious : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            tooltip: 'Next score',
            onPressed: currentIndex < totalCount - 1 ? onNext : null,
          ),
        ],
      ),
    );
  }
}
