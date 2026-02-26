import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// A single indexed entry detected within a realbook.
class IndexEntry {
  const IndexEntry({
    required this.title,
    required this.startPage,
    required this.endPage,
  });

  final String title;

  /// 1-indexed start page in the PDF.
  final int startPage;

  /// 1-indexed end page in the PDF.
  final int endPage;

  @override
  String toString() => 'IndexEntry(title: $title, pages: $startPage-$endPage)';
}

/// Service that automatically indexes a realbook PDF to detect individual
/// scores and their page ranges.
///
/// Uses a 4-tier pipeline:
/// 1. PDF bookmarks/outline
/// 2. Text extraction with heuristic title detection
/// 3. Table-of-contents page parsing
/// 4. Render-based boundary detection for text-less pages (future)
class RealbookIndexingService {
  /// Index a realbook PDF and return detected score entries.
  ///
  /// [onProgress] is called with (currentPage, totalPages) during processing.
  Future<List<IndexEntry>> indexRealbook(
    String pdfPath, {
    void Function(int current, int total)? onProgress,
  }) async {
    final doc = await PdfDocument.openFile(pdfPath);
    try {
      final totalPages = doc.pages.length;
      if (totalPages == 0) return [];

      // Tier 1: Try PDF bookmarks
      final bookmarkEntries = await _extractFromBookmarks(doc, totalPages);
      if (bookmarkEntries.isNotEmpty) {
        debugPrint(
            'RealbookIndexingService: Found ${bookmarkEntries.length} entries via bookmarks');
        return bookmarkEntries;
      }

      // Tier 2: Text extraction with heuristic title detection
      final textEntries = await _extractFromText(doc, onProgress: onProgress);
      if (textEntries.isNotEmpty) {
        debugPrint(
            'RealbookIndexingService: Found ${textEntries.length} entries via text extraction');
        return textEntries;
      }

      // Tier 3: Table-of-contents page parsing
      final tocEntries =
          await _extractFromToc(doc, totalPages, onProgress: onProgress);
      if (tocEntries.isNotEmpty) {
        debugPrint(
            'RealbookIndexingService: Found ${tocEntries.length} entries via TOC parsing');
        return tocEntries;
      }

      debugPrint(
          'RealbookIndexingService: No entries detected for $pdfPath ($totalPages pages)');
      return [];
    } finally {
      await doc.dispose();
    }
  }

  // ─── Tier 1: Bookmarks ───────────────────────────────────────────────────

  Future<List<IndexEntry>> _extractFromBookmarks(
    PdfDocument doc,
    int totalPages,
  ) async {
    final outline = await doc.loadOutline();
    if (outline.isEmpty) return [];

    // Flatten the outline tree into a sorted list of (title, pageNumber).
    final flat = <_TitlePage>[];
    void flatten(List<PdfOutlineNode> nodes) {
      for (final node in nodes) {
        if (node.dest != null && node.title.trim().isNotEmpty) {
          flat.add(_TitlePage(node.title.trim(), node.dest!.pageNumber));
        }
        if (node.children.isNotEmpty) {
          flatten(node.children);
        }
      }
    }

    flatten(outline);
    if (flat.isEmpty) return [];

    flat.sort((a, b) => a.page.compareTo(b.page));

    return _titlePagesToEntries(flat, totalPages);
  }

  // ─── Tier 2: Text extraction ─────────────────────────────────────────────

  /// Fraction of page height (from the top) to search for titles.
  static const _titleRegionFraction = 0.15;

  /// Minimum ratio of title text height to median text height to be
  /// considered a title.
  static const _titleHeightRatio = 1.3;

  Future<List<IndexEntry>> _extractFromText(
    PdfDocument doc, {
    void Function(int current, int total)? onProgress,
  }) async {
    final totalPages = doc.pages.length;
    final titlePages = <_TitlePage>[];

    for (int i = 0; i < totalPages; i++) {
      onProgress?.call(i + 1, totalPages);
      final page = doc.pages[i];
      final pageText = await page.loadText();

      final title = _detectTitleOnPage(pageText, page.height);
      if (title != null) {
        titlePages.add(_TitlePage(title, page.pageNumber));
      }
    }

    if (titlePages.isEmpty) return [];
    return _titlePagesToEntries(titlePages, totalPages);
  }

  /// Detect a title in the top region of a page by finding the largest text.
  String? _detectTitleOnPage(PdfPageText pageText, double pageHeight) {
    if (pageText.fragments.isEmpty) return null;

    // PDF coordinates: origin bottom-left, Y increases upward.
    // Top region = Y > pageHeight * (1 - fraction).
    final topThreshold = pageHeight * (1.0 - _titleRegionFraction);

    // Collect fragments in the top region.
    final topFragments = <PdfPageTextFragment>[];
    final allHeights = <double>[];

    for (final frag in pageText.fragments) {
      final h = frag.bounds.height;
      if (h > 0) allHeights.add(h);
      if (frag.bounds.top >= topThreshold && frag.text.trim().isNotEmpty) {
        topFragments.add(frag);
      }
    }

    if (topFragments.isEmpty || allHeights.isEmpty) return null;

    // Compute median text height across the full page.
    allHeights.sort();
    final medianHeight = allHeights[allHeights.length ~/ 2];
    if (medianHeight <= 0) return null;

    // Find fragments in the top region that are significantly larger than
    // the median (likely title text).
    final titleFragments = topFragments.where((f) {
      return f.bounds.height >= medianHeight * _titleHeightRatio;
    }).toList();

    if (titleFragments.isEmpty) return null;

    // Sort by position (left to right) and concatenate.
    titleFragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final title = titleFragments.map((f) => f.text.trim()).join(' ').trim();

    // Filter out common non-title text (page numbers, single chars).
    if (title.isEmpty || title.length <= 2) return null;
    if (RegExp(r'^\d+$').hasMatch(title)) return null; // pure page number

    return title;
  }

  // ─── Tier 3: Table of contents parsing ───────────────────────────────────

  /// Pattern matching TOC lines like "Song Title ......... 42" or
  /// "Song Title    42".
  static final _tocLinePattern = RegExp(r'^(.+?)\s*[.\s]{3,}\s*(\d+)\s*$');

  Future<List<IndexEntry>> _extractFromToc(
    PdfDocument doc,
    int totalPages, {
    void Function(int current, int total)? onProgress,
  }) async {
    // Scan the first few pages for TOC content.
    final maxTocPages = min(10, doc.pages.length);
    final tocEntries = <_TitlePage>[];

    for (int i = 0; i < maxTocPages; i++) {
      onProgress?.call(i + 1, totalPages);
      final page = doc.pages[i];
      final pageText = await page.loadText();
      final text = pageText.fullText;

      if (text.trim().isEmpty) continue;

      final lines = text.split('\n');
      int matchCount = 0;

      for (final line in lines) {
        final match = _tocLinePattern.firstMatch(line.trim());
        if (match != null) {
          final title = match.group(1)!.trim();
          final pageNum = int.tryParse(match.group(2)!);
          if (pageNum != null &&
              pageNum >= 1 &&
              pageNum <= totalPages &&
              title.isNotEmpty &&
              title.length > 1) {
            tocEntries.add(_TitlePage(title, pageNum));
            matchCount++;
          }
        }
      }

      // If we found at least 3 TOC-like lines on a page, treat it as TOC.
      // Otherwise, discard matches from this page (probably false positives).
      if (matchCount < 3) {
        tocEntries.removeRange(
            tocEntries.length - matchCount, tocEntries.length);
      }
    }

    if (tocEntries.isEmpty) return [];

    // Deduplicate and sort by page number.
    final seen = <String>{};
    final deduped = <_TitlePage>[];
    for (final e in tocEntries) {
      final key = '${e.title}:${e.page}';
      if (seen.add(key)) deduped.add(e);
    }
    deduped.sort((a, b) => a.page.compareTo(b.page));

    return _titlePagesToEntries(deduped, totalPages);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Convert a sorted list of (title, startPage) pairs into [IndexEntry]
  /// objects with calculated end pages.
  List<IndexEntry> _titlePagesToEntries(
      List<_TitlePage> titlePages, int totalPages) {
    final entries = <IndexEntry>[];
    for (int i = 0; i < titlePages.length; i++) {
      final endPage =
          i + 1 < titlePages.length ? titlePages[i + 1].page - 1 : totalPages;
      entries.add(IndexEntry(
        title: titlePages[i].title,
        startPage: titlePages[i].page,
        endPage: endPage,
      ));
    }
    return entries;
  }
}

class _TitlePage {
  const _TitlePage(this.title, this.page);
  final String title;
  final int page;
}
