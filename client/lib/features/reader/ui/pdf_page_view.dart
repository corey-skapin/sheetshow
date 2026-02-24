import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../core/theme/app_colors.dart';

// T040: PdfPageView widget — wraps pdfrx PdfViewer with smooth scrolling and page number overlay.

/// Full PDF viewer with smooth page navigation and page indicator.
class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.filePath,
    this.onPageChanged,
  });

  final String filePath;
  final void Function(int page, int total)? onPageChanged;

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
  void dispose() {
    super.dispose();
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
