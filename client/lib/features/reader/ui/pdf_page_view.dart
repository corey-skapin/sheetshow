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
  bool _documentReady = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _currentPage = widget.startPage ?? 1;
  }

  @override
  void didUpdateWidget(covariant PdfPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.startPage != widget.startPage) {
      _controller = PdfViewerController();
      setState(() {
        _documentReady = false;
        _currentPage = widget.startPage ?? 1;
      });
    }
  }

  /// Relative page number for display (1-based within the range).
  int get _displayPage {
    if (!widget.hasPageRange) return _currentPage;
    return (_currentPage - widget.startPage! + 1)
        .clamp(1, widget.endPage! - widget.startPage! + 1);
  }

  /// Total displayable pages.
  int get _displayTotal {
    if (!widget.hasPageRange) return _totalPages;
    return widget.endPage! - widget.startPage! + 1;
  }

  /// Custom layout that hides pages outside the [startPage]..[endPage] range.
  /// Visible pages are laid out normally from y = 0. Hidden pages get tiny
  /// rects placed far below the document area so they don't interfere.
  PdfPageLayout _layoutPages(List<PdfPage> pages, PdfViewerParams params) {
    final start = (widget.startPage! - 1).clamp(0, pages.length - 1);
    final end = (widget.endPage! - 1).clamp(start, pages.length - 1);

    const margin = 8.0;
    final rects = <Rect>[];
    double yOffset = margin;
    double maxWidth = 0;

    for (int i = 0; i < pages.length; i++) {
      if (i >= start && i <= end) {
        final page = pages[i];
        final x = (pages.fold(0.0, (w, p) => w > p.width ? w : p.width) -
                page.width) /
            2;
        rects.add(Rect.fromLTWH(x + margin, yOffset, page.width, page.height));
        yOffset += page.height + margin;
        if (page.width > maxWidth) maxWidth = page.width;
      } else {
        // Place far below the visible area. Each hidden page gets a unique
        // Y so pdfrx doesn't confuse them during intersection tests.
        rects.add(Rect.fromLTWH(0, 1e6 + i.toDouble(), 1, 1));
      }
    }

    return PdfPageLayout(
      pageLayouts: rects,
      documentSize: Size(maxWidth + margin * 2, yOffset),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use a unique key per file + page range so pdfrx creates completely
    // fresh internal state for each score (critical for realbook excerpts
    // that share the same PDF file).
    final viewerKey =
        ValueKey('${widget.filePath}:${widget.startPage}:${widget.endPage}');

    return Stack(
      children: [
        PdfViewer.file(
          widget.filePath,
          key: viewerKey,
          controller: _controller,
          initialPageNumber: widget.startPage ?? 1,
          params: PdfViewerParams(
            // Fit the entire page in view by default.
            pageAnchor: PdfPageAnchor.all,
            layoutPages: widget.hasPageRange ? _layoutPages : null,
            // Override page detection so hidden pages can't be "current".
            calculateCurrentPageNumber: widget.hasPageRange
                ? (visibleRect, pageLayouts, controller) {
                    final start = widget.startPage! - 1;
                    final end = widget.endPage! - 1;
                    int? bestPage;
                    double bestArea = 0;
                    for (int i = start;
                        i <= end && i < pageLayouts.length;
                        i++) {
                      final intersection =
                          pageLayouts[i].intersect(visibleRect);
                      if (intersection.isEmpty) continue;
                      final area = intersection.width * intersection.height;
                      if (area > bestArea) {
                        bestArea = area;
                        bestPage = i + 1;
                      }
                    }
                    return bestPage;
                  }
                : null,
            onViewerReady: (document, controller) {
              if (mounted) {
                setState(() => _documentReady = true);
              }
            },
            onDocumentChanged: (doc) {
              if (doc != null && mounted) {
                setState(() => _totalPages = doc.pages.length);
              }
            },
            onPageChanged: (page) {
              if (!mounted || page == null) return;
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
        // Loading indicator while PDF is being parsed.
        if (!_documentReady)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white70),
                SizedBox(height: 12),
                Text(
                  'Loading score…',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
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
