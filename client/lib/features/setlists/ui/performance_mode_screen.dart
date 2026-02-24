import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/reader/ui/reader_screen.dart';
import 'package:sheetshow/features/setlists/repositories/set_list_repository.dart';

// T063: PerformanceModeScreen — fullscreen set list player with prev/next controls.

/// In-memory position store: maps setListId → last viewed score index.
final _performancePositionProvider =
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
  int _currentIndex = 0;
  ScoreModel? _currentScore;
  bool _overlayVisible = true;
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
        ref.read(_performancePositionProvider)[widget.setListId] ?? 0;

    setState(() {
      _scoreIds = sl.entries.map((e) => e.scoreId).toList();
      _currentIndex =
          savedIndex.clamp(0, sl.entries.isEmpty ? 0 : sl.entries.length - 1);
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
    ref.read(_performancePositionProvider.notifier).update(
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
      child: GestureDetector(
        onTap: _showOverlay,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // PDF viewer
              if (score != null)
                ReaderScreen(
                  scoreId: score.id,
                  score: score,
                )
              else
                const Center(child: CircularProgressIndicator()),

              // Persistent back button (always visible, top-left)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                    onPressed: () => context.pop(),
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
            onPressed: currentIndex > 0 ? onPrevious : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: currentIndex < totalCount - 1 ? onNext : null,
          ),
        ],
      ),
    );
  }
}
