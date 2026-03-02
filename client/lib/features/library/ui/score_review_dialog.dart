import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/realbook_model.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/realbook_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

/// Dialog for reviewing and correcting realbook scores.
///
/// Shows all scores that need review (title not matched to a known standard).
/// The user can edit the title and page number for each score, then confirm
/// or skip. Progress is saved automatically — closing and reopening the
/// dialog resumes where the user left off.
///
/// A PDF preview on the right shows the currently selected score's page.
class ScoreReviewDialog extends ConsumerStatefulWidget {
  const ScoreReviewDialog({
    super.key,
    required this.realbookId,
    required this.realbookTitle,
  });

  final String realbookId;
  final String realbookTitle;

  @override
  ConsumerState<ScoreReviewDialog> createState() => _ScoreReviewDialogState();
}

enum _ReviewTab { needsReview, all, unallocated }

/// A range of consecutive unallocated book pages.
class _PageGap {
  const _PageGap(this.bookStart, this.bookEnd);
  final int bookStart;
  final int bookEnd;
  int get length => bookEnd - bookStart + 1;
  String get label =>
      bookStart == bookEnd ? 'p.$bookStart' : 'pp.$bookStart–$bookEnd';
}

class _ScoreReviewDialogState extends ConsumerState<ScoreReviewDialog> {
  List<ScoreModel> _scores = [];
  _ReviewTab _tab = _ReviewTab.needsReview;
  bool _loading = true;
  String? _selectedScoreId;
  int? _selectedGapPage; // PDF page for gap preview
  PdfViewerController? _pdfController;
  RealbookModel? _realbook;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _loadScores();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadScores() async {
    final repo = ref.read(scoreRepositoryProvider);
    final rbRepo = ref.read(realbookRepositoryProvider);
    final stream = repo.watchAll(realbookId: widget.realbookId);
    final scores = await stream.first;
    scores.sort((a, b) => (a.startPage ?? 0).compareTo(b.startPage ?? 0));
    final realbook = await rbRepo.getById(widget.realbookId);
    if (mounted) {
      setState(() {
        _scores = scores;
        _realbook = realbook;
        _loading = false;
        // Auto-select first unreviewed score.
        if (_selectedScoreId == null && _selectedGapPage == null) {
          final first = scores.where((s) => s.needsReview).firstOrNull;
          if (first != null) {
            _selectedScoreId = first.id;
            _goToScore(first);
          }
        }
      });
    }
  }

  void _goToScore(ScoreModel score) {
    final pdfPage = score.startPage;
    if (pdfPage != null && _pdfController != null) {
      // pdfrx uses 1-indexed page numbers.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pdfController?.goToPage(pageNumber: pdfPage);
      });
    }
  }

  List<ScoreModel> get _filteredScores => _tab == _ReviewTab.needsReview
      ? _scores.where((s) => s.needsReview).toList()
      : _scores;

  int get _reviewCount => _scores.where((s) => s.needsReview).length;

  String? get _pdfPath =>
      _realbook?.localFilePath ?? _scores.firstOrNull?.localFilePath;

  /// Compute unallocated PDF page ranges (as book page gaps).
  List<_PageGap> get _unallocatedPages {
    final rb = _realbook;
    if (rb == null) return [];
    final allocated = <bool>[for (var i = 0; i <= rb.totalPages; i++) false];
    for (final s in _scores) {
      final start = s.startPage ?? 0;
      final end = s.endPage ?? start;
      for (var p = start; p <= end && p <= rb.totalPages; p++) {
        if (p >= 1) allocated[p] = true;
      }
    }
    // Build gap ranges (as book page numbers).
    final gaps = <_PageGap>[];
    int? gapStart;
    for (var p = 1; p <= rb.totalPages; p++) {
      if (!allocated[p]) {
        gapStart ??= p;
      } else if (gapStart != null) {
        gaps.add(_PageGap(gapStart - rb.pageOffset, p - 1 - rb.pageOffset));
        gapStart = null;
      }
    }
    if (gapStart != null) {
      gaps.add(
          _PageGap(gapStart - rb.pageOffset, rb.totalPages - rb.pageOffset));
    }
    return gaps;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredScores;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Scores',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.realbookTitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (_reviewCount > 0)
                    Chip(
                      label: Text('$_reviewCount to review'),
                      backgroundColor: colorScheme.errorContainer,
                      labelStyle:
                          TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Filter toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_ReviewTab>(
                      segments: [
                        ButtonSegment(
                          value: _ReviewTab.needsReview,
                          label: Text('Review ($_reviewCount)'),
                          icon: const Icon(Icons.warning_amber_rounded),
                        ),
                        ButtonSegment(
                          value: _ReviewTab.all,
                          label: Text('All (${_scores.length})'),
                          icon: const Icon(Icons.list),
                        ),
                        ButtonSegment(
                          value: _ReviewTab.unallocated,
                          label: Text('Gaps (${_unallocatedPages.length})'),
                          icon: const Icon(Icons.help_outline),
                        ),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (v) => setState(() => _tab = v.first),
                    ),
                  ),
                  if (_tab != _ReviewTab.unallocated) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _reviewCount == 0
                          ? null
                          : () => _confirmAll(filtered),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Confirm all'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            // Main content: left panel + PDF preview
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        // Left panel
                        SizedBox(
                          width: 480,
                          child: _tab == _ReviewTab.unallocated
                              ? _buildUnallocatedList(colorScheme)
                              : _buildScoreList(filtered, colorScheme),
                        ),
                        const VerticalDivider(width: 1),
                        // PDF preview (right panel)
                        Expanded(
                          child: _pdfPath != null
                              ? PdfViewer.file(
                                  _pdfPath!,
                                  controller: _pdfController!,
                                  params: const PdfViewerParams(
                                    pageAnchor: PdfPageAnchor.all,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    'No PDF available',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveScore(ScoreModel score, String newTitle, int newBookStart,
      int newBookEnd) async {
    final repo = ref.read(scoreRepositoryProvider);
    // Convert book pages to PDF pages.
    final newStartPage = newBookStart + score.pageOffset;
    final newEndPage = newBookEnd + score.pageOffset;

    final updated = score.copyWith(
      title: newTitle,
      startPage: newStartPage,
      endPage: newEndPage,
      needsReview: false,
    );
    await repo.update(updated);
    await _loadScores();
  }

  Future<void> _confirmScore(ScoreModel score) async {
    final repo = ref.read(scoreRepositoryProvider);
    await repo.update(score.copyWith(needsReview: false));
    await _loadScores();
  }

  Future<void> _confirmAll(List<ScoreModel> scores) async {
    final repo = ref.read(scoreRepositoryProvider);
    for (final score in scores.where((s) => s.needsReview)) {
      await repo.update(score.copyWith(needsReview: false));
    }
    await _loadScores();
  }

  Widget _buildScoreList(List<ScoreModel> filtered, ColorScheme colorScheme) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            const Text('All scores have been reviewed!'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final score = filtered[index];
        return _ScoreReviewTile(
          score: score,
          isSelected: _selectedScoreId == score.id,
          onTap: () {
            setState(() {
              _selectedScoreId = score.id;
              _selectedGapPage = null;
            });
            _goToScore(score);
          },
          onSave: (title, startPage, endPage) =>
              _saveScore(score, title, startPage, endPage),
          onConfirm: () => _confirmScore(score),
        );
      },
    );
  }

  Widget _buildUnallocatedList(ColorScheme colorScheme) {
    final gaps = _unallocatedPages;
    if (gaps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            const Text('All pages are allocated!'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: gaps.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final gap = gaps[index];
        final pdfPage = gap.bookStart + (_realbook?.pageOffset ?? 0);
        final isSelected = _selectedGapPage == pdfPage;
        return Material(
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.4)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedGapPage = pdfPage;
                _selectedScoreId = null;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _pdfController?.goToPage(pageNumber: pdfPage);
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 72),
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      gap.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${gap.length} unallocated '
                      'page${gap.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => _createScoreFromGap(gap),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New score'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: () => _extendScoreWithGap(gap),
                    icon: const Icon(Icons.merge_type, size: 16),
                    label: const Text('Extend existing'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createScoreFromGap(_PageGap gap) async {
    final rb = _realbook;
    if (rb == null) return;
    final repo = ref.read(scoreRepositoryProvider);
    final scoreId = const Uuid().v4();
    final score = ScoreModel(
      id: scoreId,
      title: 'Untitled (p.${gap.bookStart})',
      filename: rb.filename,
      localFilePath: rb.localFilePath,
      totalPages: gap.length,
      updatedAt: DateTime.now(),
      realbookId: rb.id,
      startPage: gap.bookStart + rb.pageOffset,
      endPage: gap.bookEnd + rb.pageOffset,
      realbookTitle: rb.title,
      needsReview: true,
    );
    await repo.insert(score);
    await _loadScores();
    setState(() {
      _selectedScoreId = scoreId;
      _selectedGapPage = null;
      _tab = _ReviewTab.needsReview;
    });
  }

  Future<void> _extendScoreWithGap(_PageGap gap) async {
    final rb = _realbook;
    if (rb == null) return;
    final pdfStart = gap.bookStart + rb.pageOffset;
    final pdfEnd = gap.bookEnd + rb.pageOffset;
    // Find scores adjacent to this gap.
    final adjacent = _scores.where((s) {
      final se = s.endPage ?? s.startPage ?? 0;
      final ss = s.startPage ?? 0;
      return se == pdfStart - 1 || ss == pdfEnd + 1;
    }).toList();
    if (adjacent.isEmpty) {
      adjacent.addAll(_scores);
    }
    if (!mounted) return;
    final chosen = await showDialog<ScoreModel>(
      context: context,
      builder: (ctx) => _ChooseScoreDialog(
        scores: adjacent,
        allScores: _scores,
        pageOffset: rb.pageOffset,
        gap: gap,
      ),
    );
    if (chosen == null) return;
    final repo = ref.read(scoreRepositoryProvider);
    final newStart = (chosen.startPage ?? pdfStart) < pdfStart
        ? chosen.startPage!
        : pdfStart;
    final newEnd =
        (chosen.endPage ?? pdfEnd) > pdfEnd ? chosen.endPage! : pdfEnd;
    await repo.update(chosen.copyWith(
      startPage: newStart,
      endPage: newEnd,
      totalPages: newEnd - newStart + 1,
    ));
    await _loadScores();
  }
}

/// Individual row for reviewing a single score.
class _ScoreReviewTile extends StatefulWidget {
  const _ScoreReviewTile({
    required this.score,
    required this.isSelected,
    required this.onTap,
    required this.onSave,
    required this.onConfirm,
  });

  final ScoreModel score;
  final bool isSelected;
  final VoidCallback onTap;
  final Future<void> Function(String title, int bookStartPage, int bookEndPage)
      onSave;
  final VoidCallback onConfirm;

  @override
  State<_ScoreReviewTile> createState() => _ScoreReviewTileState();
}

class _ScoreReviewTileState extends State<_ScoreReviewTile> {
  late TextEditingController _titleController;
  late TextEditingController _startPageController;
  late TextEditingController _endPageController;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.score.title);
    _startPageController =
        TextEditingController(text: '${widget.score.bookPage ?? 1}');
    _endPageController = TextEditingController(
        text: '${widget.score.bookEndPage ?? widget.score.bookPage ?? 1}');
  }

  @override
  void didUpdateWidget(_ScoreReviewTile old) {
    super.didUpdateWidget(old);
    if (old.score.id != widget.score.id) {
      _titleController.text = widget.score.title;
      _startPageController.text = '${widget.score.bookPage ?? 1}';
      _endPageController.text =
          '${widget.score.bookEndPage ?? widget.score.bookPage ?? 1}';
      _editing = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = widget.score;

    return Material(
      color: widget.isSelected
          ? colorScheme.primaryContainer.withOpacity(0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Page range badge — shows book page numbers
              Container(
                constraints: const BoxConstraints(minWidth: 72),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: score.needsReview
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _editing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            child: TextField(
                              controller: _startPageController,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 6),
                                border: InputBorder.none,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          Text('–',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          SizedBox(
                            width: 32,
                            child: TextField(
                              controller: _endPageController,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 6),
                                border: InputBorder.none,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      )
                    : Text(
                        score.bookPage == score.bookEndPage ||
                                score.bookEndPage == null
                            ? 'p.${score.bookPage ?? '?'}'
                            : '${score.bookPage}–${score.bookEndPage}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: score.needsReview
                                  ? colorScheme.onErrorContainer
                                  : colorScheme.onPrimaryContainer,
                            ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Title
              Expanded(
                child: _editing
                    ? TextField(
                        controller: _titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                        ),
                        onSubmitted: (_) => _save(),
                      )
                    : Text(
                        score.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Action buttons
              if (_saving)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_editing) ...[
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Save',
                  onPressed: _save,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: () => setState(() {
                    _editing = false;
                    _titleController.text = score.title;
                    _startPageController.text = '${score.bookPage ?? 1}';
                    _endPageController.text =
                        '${score.bookEndPage ?? score.bookPage ?? 1}';
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => setState(() => _editing = true),
                  visualDensity: VisualDensity.compact,
                ),
                if (score.needsReview)
                  IconButton(
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: colorScheme.primary,
                    ),
                    tooltip: 'Confirm as correct',
                    onPressed: widget.onConfirm,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final startPage = int.tryParse(_startPageController.text.trim());
    final endPage = int.tryParse(_endPageController.text.trim());
    if (title.isEmpty || startPage == null || startPage < 1) return;

    setState(() => _saving = true);
    await widget.onSave(title, startPage, endPage ?? startPage);
    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
    }
  }
}

// ─── Choose score dialog for extending ────────────────────────────────────────

class _ChooseScoreDialog extends StatefulWidget {
  const _ChooseScoreDialog({
    required this.scores,
    required this.allScores,
    required this.pageOffset,
    required this.gap,
  });

  final List<ScoreModel> scores;
  final List<ScoreModel> allScores;
  final int pageOffset;
  final _PageGap gap;

  @override
  State<_ChooseScoreDialog> createState() => _ChooseScoreDialogState();
}

class _ChooseScoreDialogState extends State<_ChooseScoreDialog> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final scores = _showAll ? widget.allScores : widget.scores;
    final isAdjacentView =
        !_showAll && widget.scores.length < widget.allScores.length;

    return AlertDialog(
      title: Text('Extend which score with ${widget.gap.label}?'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isAdjacentView)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      'Showing adjacent scores',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      child: const Text('Show all'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: scores.length,
                itemBuilder: (ctx, i) {
                  final s = scores[i];
                  final bp = s.bookPage;
                  final bep = s.bookEndPage;
                  final range =
                      bp == bep || bep == null ? 'p.$bp' : 'pp.$bp–$bep';
                  return ListTile(
                    dense: true,
                    title: Text(s.title),
                    subtitle: Text(range),
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
