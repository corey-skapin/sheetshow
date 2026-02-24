import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/theme/app_colors.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/reader/ui/annotation_overlay.dart';
import 'package:sheetshow/features/reader/ui/annotation_toolbar.dart';
import 'package:sheetshow/features/reader/ui/pdf_page_view.dart';

// T041: ReaderScreen — full-screen PDF viewer with annotation toggle.

/// Full-screen sheet music reader with optional annotation overlay.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.scoreId,
    this.score,
  });

  final String scoreId;
  final ScoreModel? score;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  ScoreModel? _score;
  bool _annotationMode = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _score = widget.score;
    if (_score == null) _loadScore();
  }

  Future<void> _loadScore() async {
    final score =
        await ref.read(scoreRepositoryProvider).getById(widget.scoreId);
    if (mounted) setState(() => _score = score);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    if (score == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(score.title),
        actions: [
          IconButton(
            icon: Icon(
              _annotationMode ? Icons.edit_off : Icons.edit,
              color: _annotationMode ? AppColors.primary : Colors.white,
            ),
            tooltip: _annotationMode ? 'Exit Annotation' : 'Annotate',
            onPressed: () => setState(() => _annotationMode = !_annotationMode),
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF viewer
          PdfPageView(
            filePath: score.localFilePath,
            onPageChanged: (page, total) {
              if (mounted) {
                setState(() {
                  _currentPage = page;
                });
              }
            },
          ),
          // Annotation overlay
          if (_annotationMode)
            AnnotationOverlay(
              scoreId: score.id,
              pageNumber: _currentPage,
            ),
          // Annotation toolbar
          if (_annotationMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnnotationToolbar(
                scoreId: score.id,
                pageNumber: _currentPage,
              ),
            ),
        ],
      ),
    );
  }
}
