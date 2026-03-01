import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
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

class _ScoreReviewDialogState extends ConsumerState<ScoreReviewDialog> {
  List<ScoreModel> _scores = [];
  bool _showOnlyUnreviewed = true;
  bool _loading = true;
  String? _selectedScoreId;
  PdfViewerController? _pdfController;

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
    final stream = repo.watchAll(realbookId: widget.realbookId);
    final scores = await stream.first;
    scores.sort((a, b) => (a.startPage ?? 0).compareTo(b.startPage ?? 0));
    if (mounted) {
      setState(() {
        _scores = scores;
        _loading = false;
        // Auto-select first unreviewed score.
        if (_selectedScoreId == null) {
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

  List<ScoreModel> get _filteredScores => _showOnlyUnreviewed
      ? _scores.where((s) => s.needsReview).toList()
      : _scores;

  int get _reviewCount => _scores.where((s) => s.needsReview).length;

  String? get _pdfPath => _scores.firstOrNull?.localFilePath;

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
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text('Needs review ($_reviewCount)'),
                        icon: const Icon(Icons.warning_amber_rounded),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('All (${_scores.length})'),
                        icon: const Icon(Icons.list),
                      ),
                    ],
                    selected: {_showOnlyUnreviewed},
                    onSelectionChanged: (v) =>
                        setState(() => _showOnlyUnreviewed = v.first),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed:
                        _reviewCount == 0 ? null : () => _confirmAll(filtered),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Confirm all visible'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            // Main content: score list + PDF preview
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        // Score list (left panel)
                        SizedBox(
                          width: 480,
                          child: filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 48,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      const Text(
                                          'All scores have been reviewed!'),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final score = filtered[index];
                                    return _ScoreReviewTile(
                                      score: score,
                                      isSelected: _selectedScoreId == score.id,
                                      onTap: () {
                                        setState(
                                            () => _selectedScoreId = score.id);
                                        _goToScore(score);
                                      },
                                      onSave: (title, bookPage) =>
                                          _saveScore(score, title, bookPage),
                                      onConfirm: () => _confirmScore(score),
                                    );
                                  },
                                ),
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

  Future<void> _saveScore(
      ScoreModel score, String newTitle, int newBookPage) async {
    final repo = ref.read(scoreRepositoryProvider);
    // Convert book page to PDF page.
    final newStartPage = newBookPage + score.pageOffset;

    // Recalculate endPage: find the next score's startPage.
    final sortedAll = [..._scores]
      ..sort((a, b) => (a.startPage ?? 0).compareTo(b.startPage ?? 0));
    final idx = sortedAll.indexWhere((s) => s.id == score.id);
    final nextScore = idx + 1 < sortedAll.length ? sortedAll[idx + 1] : null;
    final newEndPage = nextScore != null
        ? (nextScore.startPage ?? newStartPage) - 1
        : score.endPage;

    final updated = score.copyWith(
      title: newTitle,
      startPage: newStartPage,
      endPage: newEndPage ?? newStartPage,
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
  final Future<void> Function(String title, int bookPage) onSave;
  final VoidCallback onConfirm;

  @override
  State<_ScoreReviewTile> createState() => _ScoreReviewTileState();
}

class _ScoreReviewTileState extends State<_ScoreReviewTile> {
  late TextEditingController _titleController;
  late TextEditingController _pageController;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.score.title);
    _pageController =
        TextEditingController(text: '${widget.score.bookPage ?? 1}');
  }

  @override
  void didUpdateWidget(_ScoreReviewTile old) {
    super.didUpdateWidget(old);
    if (old.score.id != widget.score.id) {
      _titleController.text = widget.score.title;
      _pageController.text = '${widget.score.bookPage ?? 1}';
      _editing = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pageController.dispose();
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
              // Page badge — shows book page number
              Container(
                width: 48,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: score.needsReview
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _editing
                    ? SizedBox(
                        width: 40,
                        child: TextField(
                          controller: _pageController,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      )
                    : Text(
                        'p.${score.bookPage ?? '?'}',
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
                    _pageController.text = '${score.bookPage ?? 1}';
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
    final bookPage = int.tryParse(_pageController.text.trim());
    if (title.isEmpty || bookPage == null || bookPage < 1) return;

    setState(() => _saving = true);
    await widget.onSave(title, bookPage);
    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
    }
  }
}
