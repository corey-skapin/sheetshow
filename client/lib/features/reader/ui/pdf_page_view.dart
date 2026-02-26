import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sheetshow/features/reader/ui/annotation_overlay.dart';

// T040: PdfPageView widget — wraps pdfrx PdfViewer with smooth scrolling and page number overlay.

/// Full PDF viewer with smooth page navigation and page indicator.
class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.filePath,
    this.onPageChanged,
    this.scoreId,
    this.annotationsVisible = false,
    this.editMode = false,
  });

  final String filePath;
  final void Function(int page, int total)? onPageChanged;

  /// Score ID used to load annotation layers; required when [annotationsVisible].
  final String? scoreId;

  /// Whether to show the annotation overlay on each page.
  final bool annotationsVisible;

  /// Whether the annotation overlay accepts pointer input for drawing.
  final bool editMode;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  late PdfViewerController _controller;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PdfViewer.file(
          widget.filePath,
          controller: _controller,
          params: PdfViewerParams(
            onDocumentChanged: (doc) {
              if (doc != null && mounted) {
                setState(() => _totalPages = doc.pages.length);
              }
            },
            onPageChanged: (page) {
              if (mounted && page != null) {
                setState(() => _currentPage = page);
                widget.onPageChanged?.call(page, _totalPages);
              }
            },
            pageOverlaysBuilder:
                (widget.annotationsVisible && widget.scoreId != null)
                    ? (context, pageRect, page) => [
                          AnnotationOverlay(
                            scoreId: widget.scoreId!,
                            pageNumber: page.pageNumber,
                            editMode: widget.editMode,
                          ),
                        ]
                    : null,
          ),
        ),
        // Page number indicator
        if (_totalPages > 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
