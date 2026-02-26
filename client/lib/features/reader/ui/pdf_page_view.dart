import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sheetshow/features/reader/ui/annotation_overlay.dart';

// T040: PdfPageView widget — wraps pdfrx PdfViewer with smooth scrolling and page number overlay.

/// Full PDF viewer with smooth page navigation and page indicator.
///
/// When [startPage] and [endPage] are set, the viewer constrains navigation
/// to that page range (for realbook excerpts). The page counter shows
/// relative numbers but annotations use absolute PDF page numbers.
class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.filePath,
    this.onPageChanged,
    this.scoreId,
    this.annotationsVisible = false,
    this.editMode = false,
    this.startPage,
    this.endPage,
  });

  final String filePath;
  final void Function(int page, int total)? onPageChanged;

  /// Score ID used to load annotation layers; required when [annotationsVisible].
  final String? scoreId;

  /// Whether to show the annotation overlay on each page.
  final bool annotationsVisible;

  /// Whether the annotation overlay accepts pointer input for drawing.
  final bool editMode;

  /// First page to show (1-indexed, inclusive). Null = show from page 1.
  final int? startPage;

  /// Last page to show (1-indexed, inclusive). Null = show to last page.
  final int? endPage;

  /// Whether this viewer is constrained to a page range.
  bool get hasPageRange => startPage != null && endPage != null;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  late PdfViewerController _controller;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _initialPageSet = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  /// Relative page number for display (1-based within the range).
  int get _displayPage {
    if (!widget.hasPageRange) return _currentPage;
    return _currentPage - widget.startPage! + 1;
  }

  /// Total displayable pages.
  int get _displayTotal {
    if (!widget.hasPageRange) return _totalPages;
    return widget.endPage! - widget.startPage! + 1;
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
                // Jump to startPage on initial load.
                if (!_initialPageSet && widget.startPage != null) {
                  _initialPageSet = true;
                  _controller.goToPage(pageNumber: widget.startPage!);
                }
              }
            },
            onPageChanged: (page) {
              if (!mounted || page == null) return;
              // Clamp navigation to the page range.
              if (widget.hasPageRange) {
                if (page < widget.startPage!) {
                  _controller.goToPage(pageNumber: widget.startPage!);
                  return;
                }
                if (page > widget.endPage!) {
                  _controller.goToPage(pageNumber: widget.endPage!);
                  return;
                }
              }
              setState(() => _currentPage = page);
              widget.onPageChanged?.call(page, _totalPages);
            },
            pageOverlaysBuilder:
                (widget.annotationsVisible && widget.scoreId != null)
                    ? (context, pageRect, page) => [
                          AnnotationOverlay(
                            scoreId: widget.scoreId!,
                            // Absolute PDF page number — annotations survive re-indexing.
                            pageNumber: page.pageNumber,
                            editMode: widget.editMode,
                          ),
                        ]
                    : null,
          ),
        ),
        // Page number indicator (shows relative numbers for realbook excerpts)
        if (_displayTotal > 0)
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
                '$_displayPage / $_displayTotal',
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
