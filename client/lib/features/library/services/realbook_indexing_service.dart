import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sheetshow/core/data/jazz_standards.dart';

/// A single indexed entry detected within a realbook.
class IndexEntry {
  const IndexEntry({
    required this.title,
    required this.startPage,
    required this.endPage,
    this.needsReview = false,
  });

  final String title;

  /// 1-indexed start page in the PDF.
  final int startPage;

  /// 1-indexed end page in the PDF.
  final int endPage;

  /// True if this entry was inferred from gap detection rather than the index.
  final bool needsReview;

  @override
  String toString() => 'IndexEntry(title: $title, pages: $startPage-$endPage'
      '${needsReview ? ', REVIEW' : ''})';
}

/// Service that automatically indexes a realbook PDF to detect individual
/// scores and their page ranges.
///
/// Uses a 4-tier pipeline:
/// 1. PDF bookmarks/outline
/// 2. Text extraction with heuristic title detection
/// 3. Table-of-contents page parsing
/// 4. Staff-line scan + OCR for scanned/handwritten pages
class RealbookIndexingService {
  RealbookIndexingService({required this.ocrExePath});

  /// Path to the SheetShowOcr.exe executable for Windows OCR.
  final String ocrExePath;

  /// Index a realbook PDF and return detected score entries.
  ///
  /// [onProgress] is called with (currentPage, totalPages) during processing.
  Future<List<IndexEntry>> indexRealbook(
    String pdfPath, {
    int pageOffset = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    PdfDocument doc;
    try {
      doc = await PdfDocument.openFile(pdfPath);
    } catch (e) {
      debugPrint('RealbookIndexingService: PdfDocument.openFile failed: $e');
      // pdfium can't open this PDF — try OCR-only fallback using the
      // external OCR tool (which uses Windows.Data.Pdf, a different engine).
      return _indexWithOcrOnly(pdfPath,
          pageOffset: pageOffset, onProgress: onProgress);
    }
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

      // Tier 3: Table-of-contents page parsing (text-based)
      final tocEntries = await _extractFromToc(doc, totalPages,
          pageOffset: pageOffset, onProgress: onProgress);
      if (tocEntries.isNotEmpty) {
        debugPrint(
            'RealbookIndexingService: Found ${tocEntries.length} entries via TOC parsing');
        return tocEntries;
      }

      // Tier 4: OCR-based index reading (for scanned books with index pages)
      final ocrIndexEntries = await _extractFromOcrIndex(
          doc, totalPages, pdfPath,
          pageOffset: pageOffset, onProgress: onProgress);
      if (ocrIndexEntries.isNotEmpty) {
        debugPrint(
            'RealbookIndexingService: Found ${ocrIndexEntries.length} entries via OCR index');
        return ocrIndexEntries;
      }

      // Tier 5: Staff-line scan + OCR for scanned/handwritten pages (fallback)
      final scanEntries = await _extractFromScan(doc, onProgress: onProgress);
      if (scanEntries.isNotEmpty) {
        debugPrint(
            'RealbookIndexingService: Found ${scanEntries.length} entries via staff-line scan + OCR');
        return scanEntries;
      }

      debugPrint(
          'RealbookIndexingService: No entries detected for $pdfPath ($totalPages pages)');
      return [];
    } finally {
      await doc.dispose();
    }
  }

  /// Fallback indexing when pdfium can't open the PDF.
  /// Uses only the external OCR tool (which relies on Windows.Data.Pdf)
  /// to scan index pages and detect scores.
  Future<List<IndexEntry>> _indexWithOcrOnly(
    String pdfPath, {
    int pageOffset = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    debugPrint('RealbookIndexingService: Using OCR-only fallback for $pdfPath');

    // We need the total page count — use the byte-scan fallback from
    // ImportService, or try to get it from the OCR tool's error output.
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final typeBytes = '/Type'.codeUnits;
    final pageBytes = '/Page'.codeUnits;
    int totalPages = 0;
    for (int i = 0; i < bytes.length - 12; i++) {
      if (_bytesMatchFallback(bytes, i, typeBytes)) {
        int j = i + typeBytes.length;
        while (j < bytes.length &&
            (bytes[j] == 32 ||
                bytes[j] == 10 ||
                bytes[j] == 13 ||
                bytes[j] == 9)) {
          j++;
        }
        if (j < bytes.length - 5 && _bytesMatchFallback(bytes, j, pageBytes)) {
          final afterPage = j + pageBytes.length;
          if (afterPage < bytes.length && bytes[afterPage] != 0x73) {
            totalPages++;
          }
        }
      }
    }
    if (totalPages == 0) return [];
    debugPrint('RealbookIndexingService: OCR-only fallback, '
        '$totalPages pages detected');

    // Scan front and back pages for index content using OCR only.
    final frontEnd = min(_maxIndexScanPages, totalPages);
    final backStart = max(frontEnd, totalPages - _maxIndexScanPages);
    final pagesToScan = <int>[
      for (int i = 0; i < frontEnd; i++) i,
      for (int i = backStart; i < totalPages; i++)
        if (i >= frontEnd) i,
    ];

    final progressTotal = pagesToScan.length;
    final allTocEntries = <_TitlePage>[];
    int indexPageCount = 0;

    final logFile =
        File('${Directory.systemTemp.path}/sheetshow_index_log.txt');
    final logSink = logFile.openWrite();
    logSink.writeln('=== Realbook Index Scan (OCR-only fallback): '
        '$totalPages pages ===');
    logSink.writeln('Scanning pages: $pagesToScan');

    for (int idx = 0; idx < pagesToScan.length; idx++) {
      final pageIdx = pagesToScan[idx];
      onProgress?.call(idx + 1, progressTotal);

      // OCR the page directly (1-indexed).
      final text = await _ocrPdfPage(pageIdx + 1, pdfPath, logSink) ?? '';

      logSink.writeln('\n--- Page ${pageIdx + 1} (OCR-only) ---');
      logSink.writeln(text.isEmpty ? '(empty)' : text);

      if (text.trim().isEmpty) continue;

      final lines = text.split('\n');
      int matchCount = 0;
      String orphan = '';
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final input = orphan.isNotEmpty ? '$orphan $trimmed' : trimmed;
        final pairs = _parseIndexLine(input, totalPages, pageOffset);
        if (pairs.isEmpty) {
          final cleaned = _cleanIndexTitle(trimmed);
          if (cleaned.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(cleaned)) {
            orphan = orphan.isNotEmpty ? '$orphan $cleaned' : cleaned;
            if (orphan.length > 60) {
              logSink.writeln('  ORPHAN: "$cleaned" (discarded — too long)');
              orphan = '';
            } else {
              logSink.writeln('  ORPHAN: "$cleaned" (buffered for next line)');
            }
          }
          continue;
        }

        orphan = '';
        for (final pair in pairs) {
          if (RegExp(r'^\d+$').hasMatch(pair.title)) continue;
          logSink.writeln('  MATCH: "${pair.title}" -> PDF page ${pair.page}');
          allTocEntries.add(pair);
          matchCount++;
        }
      }

      logSink.writeln('  => $matchCount matches on page ${pageIdx + 1}');
      if (matchCount >= 3) indexPageCount++;
    }

    logSink.writeln('\n=== RESULT: ${allTocEntries.length} entries, '
        '$indexPageCount index pages ===');
    if (allTocEntries.length < _minIndexEntries || indexPageCount < 1) {
      logSink.writeln('FAILED: Not enough entries (need >= $_minIndexEntries)');
      await logSink.flush();
      await logSink.close();
      return [];
    }

    // Deduplicate.
    final seen = <String>{};
    final deduped = <_TitlePage>[];
    final byPage = <int, _TitlePage>{};
    for (final e in allTocEntries) {
      final key = '${e.title.toLowerCase()}:${e.page}';
      if (!seen.add(key)) continue;
      final existing = byPage[e.page];
      if (existing == null) {
        byPage[e.page] = e;
        deduped.add(e);
      } else {
        final existingScore = _titleQuality(existing.title);
        final newScore = _titleQuality(e.title);
        if (newScore > existingScore) {
          deduped.remove(existing);
          byPage[e.page] = e;
          deduped.add(e);
        }
      }
    }
    deduped.sort((a, b) => a.page.compareTo(b.page));

    // Normalize titles.
    final normalized = deduped.map((e) {
      var title =
          e.title == e.title.toUpperCase() ? _toTitleCase(e.title) : e.title;
      final match = JazzStandards.fuzzyMatch(title);
      var matched = false;
      if (match != null && match.toLowerCase() != title.toLowerCase()) {
        logSink.writeln('  FUZZY: "$title" -> "$match"');
        title = match;
        matched = true;
      } else if (match != null) {
        matched = true;
      }
      return _TitlePage(title, e.page, matched: matched);
    }).toList();

    final entries = _titlePagesToEntries(normalized, totalPages);
    // No gap-filling in OCR-only mode (needs PdfDocument for staff scanning).
    final result = _addGapEntries(entries, totalPages);
    await logSink.flush();
    await logSink.close();
    return result;
  }

  static bool _bytesMatchFallback(List<int> data, int offset, List<int> pat) {
    if (offset + pat.length > data.length) return false;
    for (int i = 0; i < pat.length; i++) {
      if (data[offset + i] != pat[i]) return false;
    }
    return true;
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
    int pageOffset = 0,
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
          final bookPageNum = int.tryParse(match.group(2)!);
          if (bookPageNum != null && title.isNotEmpty && title.length > 1) {
            final pdfPage = bookPageNum + pageOffset;
            if (pdfPage >= 1 && pdfPage <= totalPages) {
              tocEntries.add(_TitlePage(title, pdfPage));
              matchCount++;
            }
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

  // ─── Tier 4: OCR-based index reading ──────────────────────────────────────

  /// Maximum pages to scan for index content at front and back of book.
  static const _maxIndexScanPages = 15;

  /// Minimum number of TOC-like entries required across index pages.
  static const _minIndexEntries = 5;

  /// Pattern to find standalone page-number candidates in a line.
  /// Excludes numbers embedded in hyphenated/slashed tokens (e.g. "12-4").
  static final _pageNumberCandidate =
      RegExp(r'(?<![/\-])\b(\d{1,4})\b(?![/\-])');

  /// Words that should not be treated as score titles in index parsing.
  static final _indexNoiseWords = RegExp(
    r'^(index|contents|table of contents|page|copyright|introduction|'
    r'foreword|preface|appendix|about|notation|symbols|chord|cont)\b',
    caseSensitive: false,
  );

  /// Parse a single index line into title→page pairs.
  ///
  /// Handles multi-column lines ("TITLE1 42 TITLE2 43") and titles that
  /// contain numbers ("502 Blues 153"). Works by finding candidate page
  /// numbers first, then assigning the text before each as its title.
  /// If a candidate has no valid title text (empty or too short), its number
  /// is merged into the next title — it was part of the song name, not a page.
  static List<_TitlePage> _parseIndexLine(
    String line,
    int totalPages,
    int pageOffset,
  ) {
    // Strip dot leaders (e.g. "Title.......42") before parsing —
    // they appear in many realbook index layouts.
    line = line
        .replaceAll(RegExp(r'\.{2,}'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Find all standalone numbers within the valid page range.
    final candidates = <({int number, int start, int end})>[];
    for (final m in _pageNumberCandidate.allMatches(line)) {
      final num = int.parse(m.group(1)!);
      final pdfPage = num + pageOffset;
      if (pdfPage >= 1 && pdfPage <= totalPages) {
        candidates.add((number: num, start: m.start, end: m.end));
      }
    }
    if (candidates.isEmpty) return [];

    // Extract text segments between consecutive number candidates.
    final results = <_TitlePage>[];
    String carry = '';

    for (int i = 0; i < candidates.length; i++) {
      // Text between previous candidate's end and this candidate's start.
      final segStart = i == 0 ? 0 : candidates[i - 1].end;
      var segment = line.substring(segStart, candidates[i].start);

      // Prepend any carried-over text (number that wasn't a page number).
      var title =
          carry + (carry.isNotEmpty && segment.isNotEmpty ? ' ' : '') + segment;
      title = _cleanIndexTitle(title);

      final hasLetters = RegExp(r'[A-Za-z]').hasMatch(title);
      final isValidTitle = title.length >= 3 && hasLetters;
      final isLast = i == candidates.length - 1;

      if (isValidTitle) {
        if (!_indexNoiseWords.hasMatch(title)) {
          results.add(_TitlePage(title, candidates[i].number + pageOffset));
        }
        carry = '';
      } else if (!isLast) {
        // Not a valid title → this number is part of the next song's name.
        carry = '${title.isNotEmpty ? '$title ' : ''}${candidates[i].number}';
      } else {
        carry = '';
      }
    }

    return results;
  }

  /// Clean OCR artifacts from an index title string.
  static String _cleanIndexTitle(String title) {
    return title
        .replaceAll(RegExp(r'[|_~]'), '')
        .replaceAll(RegExp(r'\.{2,}'), ' ') // collapse dot leaders
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s.,·…\-—]+'), '')
        .replaceAll(RegExp(r'[\s.,·…\-—]+$'), '')
        .trim();
  }

  Future<List<IndexEntry>> _extractFromOcrIndex(
    PdfDocument doc,
    int totalPages,
    String pdfPath, {
    int pageOffset = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    // Scan front and back of the book for index pages.
    final frontEnd = min(_maxIndexScanPages, totalPages);
    final backStart = max(frontEnd, totalPages - _maxIndexScanPages);
    final pagesToScan = <int>[
      for (int i = 0; i < frontEnd; i++) i,
      for (int i = backStart; i < totalPages; i++)
        if (i >= frontEnd) i,
    ];

    final progressTotal = pagesToScan.length;
    final allTocEntries = <_TitlePage>[];
    int indexPageCount = 0;

    // Log file for diagnostics (helps debug OCR issues in release builds).
    final logFile =
        File('${Directory.systemTemp.path}/sheetshow_index_log.txt');
    final logSink = logFile.openWrite();
    logSink.writeln('=== Realbook Index Scan: $totalPages pages ===');
    logSink.writeln('Scanning pages: $pagesToScan');

    for (int idx = 0; idx < pagesToScan.length; idx++) {
      final pageIdx = pagesToScan[idx];
      onProgress?.call(idx + 1, progressTotal);

      final page = doc.pages[pageIdx];

      // First check if we already have selectable text (skip OCR).
      final pageText = await page.loadText();
      String text = pageText.fullText;
      final hadText = text.trim().isNotEmpty;

      // If no selectable text, OCR the full page via the external tool
      // which renders the PDF page internally using Windows.Data.Pdf.
      if (!hadText) {
        text = await _ocrPdfPage(
                doc.pages[pageIdx].pageNumber, pdfPath, logSink) ??
            '';
      }

      logSink.writeln(
          '\n--- Page ${pageIdx + 1} (${hadText ? "text" : "OCR"}) ---');
      logSink.writeln(text.isEmpty ? '(empty)' : text);

      if (text.trim().isEmpty) continue;

      // Parse all "Title PageNum" pairs from each line using the
      // column-aware parser that handles titles containing numbers.
      // Lines with no page number are buffered as "orphans" and prepended
      // to the next line — they are likely title continuations from a
      // multi-line title in the index.
      final lines = text.split('\n');
      int matchCount = 0;
      String orphan = '';
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Prepend any orphan text from the previous line.
        final input = orphan.isNotEmpty ? '$orphan $trimmed' : trimmed;

        final pairs = _parseIndexLine(input, totalPages, pageOffset);
        if (pairs.isEmpty) {
          // No page numbers found — this line is likely a title continuation.
          // Only buffer text that looks like title content (has letters).
          final cleaned = _cleanIndexTitle(trimmed);
          if (cleaned.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(cleaned)) {
            orphan = orphan.isNotEmpty ? '$orphan $cleaned' : cleaned;
            // Cap orphan length — real continuations are short (e.g. "HEART").
            // Long orphans are from non-index text and should be discarded.
            if (orphan.length > 60) {
              logSink.writeln('  ORPHAN: "$cleaned" (discarded — too long)');
              orphan = '';
            } else {
              logSink.writeln('  ORPHAN: "$cleaned" (buffered for next line)');
            }
          }
          continue;
        }

        orphan = '';
        for (final pair in pairs) {
          // Skip titles that are just numbers after cleaning.
          if (RegExp(r'^\d+$').hasMatch(pair.title)) continue;

          logSink.writeln('  MATCH: "${pair.title}" -> PDF page ${pair.page}');
          allTocEntries.add(pair);
          matchCount++;
        }
      }

      logSink.writeln('  => $matchCount matches on page ${pageIdx + 1}');
      if (matchCount >= 3) indexPageCount++;
    }

    // Need enough entries and at least one page that looked like an index.
    logSink.writeln('\n=== RESULT: ${allTocEntries.length} entries, '
        '$indexPageCount index pages ===');
    if (allTocEntries.length < _minIndexEntries || indexPageCount < 1) {
      logSink.writeln('FAILED: Not enough entries (need >= $_minIndexEntries)');
      await logSink.flush();
      await logSink.close();
      return [];
    }

    for (final e in allTocEntries) {
      logSink.writeln('  "${e.title}" -> page ${e.page}');
    }

    debugPrint(
        'RealbookIndexingService: OCR index found ${allTocEntries.length} '
        'entries across $indexPageCount index pages');
    debugPrint('RealbookIndexingService: Log written to ${logFile.path}');

    // Deduplicate: same title+page is exact dup; same page with different
    // titles keeps the longer one (likely more complete OCR read).
    final seen = <String>{};
    final deduped = <_TitlePage>[];
    final byPage = <int, _TitlePage>{};
    for (final e in allTocEntries) {
      final key = '${e.title.toLowerCase()}:${e.page}';
      if (!seen.add(key)) continue; // exact duplicate

      final existing = byPage[e.page];
      if (existing == null) {
        byPage[e.page] = e;
        deduped.add(e);
      } else {
        // Prefer entries that look like real titles: mostly alphabetic,
        // reasonable length. Score the existing vs new entry.
        final existingScore = _titleQuality(existing.title);
        final newScore = _titleQuality(e.title);
        if (newScore > existingScore) {
          deduped.remove(existing);
          byPage[e.page] = e;
          deduped.add(e);
          logSink.writeln(
              '  DEDUP: page ${e.page}: "${existing.title}" -> "${e.title}"');
        }
      }
    }
    deduped.sort((a, b) => a.page.compareTo(b.page));

    // Normalize titles: Title Case for ALL-CAPS, then fuzzy-match against
    // known jazz standards to correct OCR misreads.
    final normalized = deduped.map((e) {
      var title =
          e.title == e.title.toUpperCase() ? _toTitleCase(e.title) : e.title;
      final match = JazzStandards.fuzzyMatch(title);
      var matched = false;
      if (match != null && match.toLowerCase() != title.toLowerCase()) {
        logSink.writeln('  FUZZY: "$title" -> "$match"');
        title = match;
        matched = true;
      } else if (match != null) {
        matched = true;
      }
      return _TitlePage(title, e.page, matched: matched);
    }).toList();

    // Build entries and detect gaps (unaccounted pages).
    // For gap pages, run a targeted scan (staff-line + title OCR) to try
    // to identify scores that the index parsing missed.
    final entries = _titlePagesToEntries(normalized, totalPages);
    logSink.writeln('\n=== Gap-filling scan ===');
    final result = await _fillGaps(entries, doc, totalPages, logSink);
    await logSink.flush();
    await logSink.close();
    return result;
  }

  /// Score a title's quality: higher = more likely a real song title.
  /// Prefers titles that are mostly alphabetic, reasonable length (5-40 chars),
  /// and don't contain excessive punctuation or digits.
  static double _titleQuality(String title) {
    if (title.isEmpty) return 0;
    final alphaCount = title.runes
        .where((r) => RegExp(r'[a-zA-Z]').hasMatch(String.fromCharCode(r)))
        .length;
    final alphaRatio = alphaCount / title.length;
    // Penalize very short or very long titles.
    final lengthScore = title.length >= 5 && title.length <= 40 ? 1.0 : 0.5;
    return alphaRatio * lengthScore;
  }

  /// Convert ALL-CAPS text to Title Case, preserving small words lowercase.
  static String _toTitleCase(String text) {
    const smallWords = {
      'a',
      'an',
      'the',
      'and',
      'but',
      'or',
      'nor',
      'for',
      'yet',
      'so',
      'in',
      'on',
      'at',
      'to',
      'of',
      'by',
      'up',
      'de',
      'en',
      'is',
    };
    final words = text.toLowerCase().split(' ');
    return words.asMap().entries.map((e) {
      final word = e.value;
      // Always capitalize first and last word; lowercase small words.
      if (e.key == 0 ||
          e.key == words.length - 1 ||
          !smallWords.contains(word)) {
        return word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}';
      }
      return word;
    }).join(' ');
  }

  /// Run OCR on a PDF page by calling the external tool in PDF mode.
  /// The tool renders the page internally using Windows.Data.Pdf at high
  /// resolution, then applies binarization and OCR.
  Future<String?> _ocrPdfPage(int pageNumber, String pdfPath,
      [IOSink? log]) async {
    log?.writeln('  [OCR] Running OCR on PDF page $pageNumber...');

    try {
      final result = await Process.run(ocrExePath, [pdfPath, '$pageNumber']);
      if (result.exitCode != 0) {
        log?.writeln('  [OCR] FAILED exit=${result.exitCode}: '
            '${result.stderr}');
        return null;
      }
      final text = result.stdout as String;
      log?.writeln('  [OCR] Got ${text.length} chars');
      return text;
    } catch (e) {
      log?.writeln('  [OCR] EXCEPTION: $e');
      return null;
    }
  }

  /// Given entries from an index, find page gaps where no score is assigned
  /// and insert review-flagged placeholder entries.
  List<IndexEntry> _addGapEntries(List<IndexEntry> entries, int totalPages) {
    if (entries.isEmpty) return entries;

    final result = <IndexEntry>[];
    final assigned = <int>{};

    for (final e in entries) {
      for (int p = e.startPage; p <= e.endPage; p++) {
        assigned.add(p);
      }
    }

    // Don't flag the first few pages (index/TOC pages themselves) or
    // the last page (often a back cover).
    final firstScorePage = entries.first.startPage;
    final lastScorePage = entries.last.endPage;

    int gapStart = -1;
    for (int p = firstScorePage; p <= lastScorePage; p++) {
      if (!assigned.contains(p)) {
        if (gapStart == -1) gapStart = p;
      } else {
        if (gapStart != -1) {
          result.add(IndexEntry(
            title: 'Unindexed (pages $gapStart–${p - 1})',
            startPage: gapStart,
            endPage: p - 1,
            needsReview: true,
          ));
          gapStart = -1;
        }
      }
    }
    if (gapStart != -1) {
      result.add(IndexEntry(
        title: 'Unindexed (pages $gapStart–$lastScorePage)',
        startPage: gapStart,
        endPage: lastScorePage,
        needsReview: true,
      ));
    }

    // Merge indexed entries and gap entries, sorted by start page.
    result.addAll(entries);
    result.sort((a, b) => a.startPage.compareTo(b.startPage));

    final reviewCount = result.where((e) => e.needsReview).length;
    if (reviewCount > 0) {
      debugPrint(
          'RealbookIndexingService: $reviewCount gap entries flagged for review');
    }

    return result;
  }

  /// After the initial OCR index, find pages with no score assigned and
  /// run a targeted staff-line + title-OCR scan on them to recover missing
  /// entries. Pages that have staves but weren't in the index get their
  /// title read from the top of the page; pages without staves are skipped
  /// (likely intro/blank/index pages).
  Future<List<IndexEntry>> _fillGaps(
    List<IndexEntry> entries,
    PdfDocument doc,
    int totalPages,
    IOSink logSink,
  ) async {
    if (entries.isEmpty) return entries;

    // Find which pages are already covered.
    final assigned = <int>{};
    for (final e in entries) {
      for (int p = e.startPage; p <= e.endPage; p++) {
        assigned.add(p);
      }
    }

    final firstScorePage = entries.first.startPage;
    final lastScorePage = entries.last.endPage;

    // Collect unassigned pages within the score range.
    final gapPages = <int>[];
    for (int p = firstScorePage; p <= lastScorePage; p++) {
      if (!assigned.contains(p)) gapPages.add(p);
    }

    if (gapPages.isEmpty) {
      logSink.writeln('No gap pages to scan');
      return entries;
    }

    logSink.writeln('Scanning ${gapPages.length} gap pages: $gapPages');

    // Classify each gap page (staff-line detection).
    final recovered = <_TitlePage>[];
    for (final pageNum in gapPages) {
      if (pageNum < 1 || pageNum > doc.pages.length) continue;
      final page = doc.pages[pageNum - 1]; // 0-indexed

      final info = await _classifyPage(page);
      if (!info.hasStaves) {
        logSink.writeln('  Gap page $pageNum: no staves (skipped)');
        continue;
      }

      // This page has music notation — try to read its title.
      String? title;
      if (info.isScoreStart) {
        title = await _ocrTitleRegion(page, info.firstStaffFraction);
        // Try fuzzy matching against known jazz standards.
        if (title != null && title.isNotEmpty) {
          final match = JazzStandards.fuzzyMatch(title);
          if (match != null) {
            logSink.writeln('  Gap page $pageNum: fuzzy "$title" -> "$match"');
            title = match;
          }
        }
      }

      final displayTitle =
          (title != null && title.isNotEmpty) ? title : 'Page $pageNum';
      logSink.writeln('  Gap page $pageNum: staves=${info.hasStaves}, '
          'scoreStart=${info.isScoreStart}, title="$displayTitle"');
      recovered.add(_TitlePage(displayTitle, pageNum));
    }

    if (recovered.isEmpty) {
      logSink.writeln('No scores recovered from gap pages');
      return _addGapEntries(entries, totalPages);
    }

    logSink.writeln('Recovered ${recovered.length} scores from gap pages');

    // Merge recovered entries with existing ones and rebuild.
    final allTitlePages = <_TitlePage>[
      ...entries.map((e) => _TitlePage(e.title, e.startPage)),
      ...recovered,
    ];
    allTitlePages.sort((a, b) => a.page.compareTo(b.page));
    final merged = _titlePagesToEntries(allTitlePages, totalPages);
    return _addGapEntries(merged, totalPages);
  }

  // ─── Tier 5: Staff-line scan + OCR (fallback) ─────────────────────────────

  /// Render width for the low-res staff-line detection pass.
  static const _scanWidth = 200;

  /// Minimum fraction of row pixels that must be dark to count as a
  /// horizontal line. Staff lines span most of the page width. Lowered
  /// to handle faded or broken lines in scanned realbooks.
  static const _lineMinFill = 0.15;

  /// Dark pixel threshold (0-255). Pixel brightness below this = dark.
  static const _darkThreshold = 128;

  /// Minimum staff line groups (sets of ~5 lines) to classify a page as
  /// containing music notation.
  static const _minStaffGroups = 1;

  /// The fraction of page height from the top used for title detection.
  /// This is the minimum gap above the first staff system for a page to be
  /// considered a score start. Lowered from 0.22 to catch compact titles.
  static const _scanTitleRegion = 0.10;

  /// Render width for the title-region OCR crop.
  static const _ocrRenderWidth = 600;

  Future<List<IndexEntry>> _extractFromScan(
    PdfDocument doc, {
    void Function(int current, int total)? onProgress,
  }) async {
    final totalPages = doc.pages.length;

    // Pass 1: Classify every page via staff-line detection.
    // _PageInfo records whether the page has staves and where the first
    // staff system starts (as a fraction of page height from the top).
    final pageInfos = <_PageInfo>[];
    for (int i = 0; i < totalPages; i++) {
      onProgress?.call(i + 1, totalPages * 2); // first half of progress
      final page = doc.pages[i];
      final info = await _classifyPage(page);
      pageInfos.add(info);
    }

    // Compute a baseline "typical staff start" from all music pages.
    // Continuation pages have staves near the top; score-start pages have
    // a gap for the title. We use the 25th-percentile of staff start
    // positions as the baseline (most pages are continuations).
    final staffStarts = <double>[];
    for (final info in pageInfos) {
      if (info.hasStaves && info.firstStaffFraction > 0.01) {
        staffStarts.add(info.firstStaffFraction);
      }
    }

    // Adaptive threshold: baseline + a margin, or the fixed minimum.
    double adaptiveThreshold = _scanTitleRegion;
    if (staffStarts.length >= 5) {
      staffStarts.sort();
      final baseline = staffStarts[(staffStarts.length * 0.25).floor()];
      // A page is a score start if its staff starts noticeably lower than
      // the baseline (continuation pages). Require at least 5% more gap.
      final adaptive = baseline + 0.05;
      adaptiveThreshold =
          adaptive > _scanTitleRegion ? adaptive : _scanTitleRegion;
      debugPrint(
          'RealbookIndexingService: Adaptive threshold=$adaptiveThreshold '
          '(baseline=$baseline, pages with staves=${staffStarts.length})');
    }

    // Find score boundary pages: a score page whose first staff system
    // starts significantly lower than the baseline (leaving room for a title).
    final boundaryIndices = <int>[];
    for (int i = 0; i < totalPages; i++) {
      final info = pageInfos[i];
      if (!info.hasStaves) continue;
      if (info.firstStaffFraction >= adaptiveThreshold) {
        boundaryIndices.add(i);
      } else if (boundaryIndices.isEmpty) {
        // First music page, even without a title gap, starts a score.
        boundaryIndices.add(i);
      }
    }

    if (boundaryIndices.isEmpty) return [];

    // Pass 2: OCR the title region of each boundary page.
    final titlePages = <_TitlePage>[];
    for (int idx = 0; idx < boundaryIndices.length; idx++) {
      final pageIdx = boundaryIndices[idx];
      final page = doc.pages[pageIdx];
      final firstStaffY = pageInfos[pageIdx].firstStaffFraction;
      onProgress?.call(
          totalPages + idx + 1, totalPages + boundaryIndices.length);

      final title = await _ocrTitleRegion(page, firstStaffY);
      final displayTitle = (title != null && title.isNotEmpty)
          ? title
          : 'Page ${page.pageNumber}';
      titlePages.add(_TitlePage(displayTitle, page.pageNumber));
    }

    return _titlePagesToEntries(titlePages, totalPages);
  }

  /// Classify a page by rendering at low resolution and scanning for
  /// horizontal staff lines.
  Future<_PageInfo> _classifyPage(PdfPage page) async {
    final scale = _scanWidth / page.width;
    const renderW = _scanWidth;
    final renderH = (page.height * scale).round();

    final image = await page.render(
      fullWidth: renderW.toDouble(),
      fullHeight: renderH.toDouble(),
    );
    if (image == null) return const _PageInfo(false, 0);

    try {
      final pixels = image.pixels;
      final w = image.width;
      final h = image.height;
      final isBgra = image.format == ui.PixelFormat.bgra8888;

      // For each row, compute the fraction of dark pixels.
      final rowDarkFraction = Float64List(h);
      for (int y = 0; y < h; y++) {
        int darkCount = 0;
        for (int x = 0; x < w; x++) {
          final offset = (y * w + x) * 4;
          // Read RGB (handle BGRA vs RGBA).
          final r = isBgra ? pixels[offset + 2] : pixels[offset];
          final g = pixels[offset + 1];
          final b = isBgra ? pixels[offset] : pixels[offset + 2];
          final brightness = (r * 299 + g * 587 + b * 114) ~/ 1000;
          if (brightness < _darkThreshold) darkCount++;
        }
        rowDarkFraction[y] = darkCount / w;
      }

      // Find horizontal dark rows (staff line candidates).
      final darkRows = <int>[];
      for (int y = 0; y < h; y++) {
        if (rowDarkFraction[y] >= _lineMinFill) {
          darkRows.add(y);
        }
      }

      // Group consecutive dark rows into line clusters. A staff line at
      // low resolution is typically 1-3 px tall.
      final clusters = _clusterRows(darkRows, maxGap: 2);

      // Try to find staff groups: 5 clusters with roughly equal spacing.
      int staffGroupCount = 0;
      int firstStaffRow = -1;
      int i = 0;
      while (i + 4 < clusters.length) {
        final spacings = <int>[];
        for (int j = 0; j < 4; j++) {
          spacings.add(clusters[i + j + 1] - clusters[i + j]);
        }
        // Check if spacings are roughly equal (within 40% of median).
        spacings.sort();
        final medianSpacing = spacings[2];
        final allClose = spacings.every((s) =>
            (s - medianSpacing).abs() < (medianSpacing * 0.4).round() + 1);
        if (allClose && medianSpacing > 2 && medianSpacing < h ~/ 4) {
          staffGroupCount++;
          if (firstStaffRow == -1) firstStaffRow = clusters[i];
          i += 5; // skip past this staff group
        } else {
          i++;
        }
      }

      final hasStaves = staffGroupCount >= _minStaffGroups;
      final firstStaffFraction =
          hasStaves && firstStaffRow >= 0 ? firstStaffRow / h : 0.0;
      // A page is a "score start" if there's a title-sized gap above staves.
      final isScoreStart = hasStaves && firstStaffFraction >= _scanTitleRegion;

      return _PageInfo(hasStaves, firstStaffFraction, isScoreStart);
    } finally {
      image.dispose();
    }
  }

  /// Cluster a sorted list of row indices into groups of consecutive rows
  /// (within [maxGap] pixels). Returns the center row of each cluster.
  List<int> _clusterRows(List<int> rows, {int maxGap = 2}) {
    if (rows.isEmpty) return [];
    final centers = <int>[];
    int start = rows[0];
    int end = rows[0];
    for (int i = 1; i < rows.length; i++) {
      if (rows[i] - end <= maxGap) {
        end = rows[i];
      } else {
        centers.add((start + end) ~/ 2);
        start = rows[i];
        end = rows[i];
      }
    }
    centers.add((start + end) ~/ 2);
    return centers;
  }

  /// Render the title region of a page at higher resolution, save as a
  /// temporary PNG, and run Windows OCR on it via the SheetShowOcr tool.
  Future<String?> _ocrTitleRegion(
    PdfPage page,
    double firstStaffFraction,
  ) async {
    // Render the full page at OCR resolution.
    final scale = _ocrRenderWidth / page.width;
    const fullW = _ocrRenderWidth;
    final fullH = (page.height * scale).round();

    // Only render the title region (top portion above first staff system).
    final cropFraction =
        firstStaffFraction > 0.05 ? firstStaffFraction : _scanTitleRegion;
    final cropH = (fullH * cropFraction).round();
    if (cropH < 10) return null;

    final image = await page.render(
      fullWidth: fullW.toDouble(),
      fullHeight: fullH.toDouble(),
      x: 0,
      y: 0,
      width: fullW,
      height: cropH,
    );
    if (image == null) return null;

    File? tempFile;
    try {
      // Encode the crop as PNG.
      final uiImage = await image.createImage();
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // Write to a temp file for the OCR subprocess.
      tempFile = File(
          '${Directory.systemTemp.path}/sheetshow_ocr_${page.pageNumber}.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      // Run OCR via subprocess.
      final result = await Process.run(ocrExePath, [tempFile.path]);
      if (result.exitCode != 0) {
        debugPrint('OCR failed for page ${page.pageNumber}: ${result.stderr}');
        return null;
      }

      return _cleanOcrTitle(result.stdout as String);
    } finally {
      image.dispose();
      tempFile?.deleteSync();
    }
  }

  /// Clean up raw OCR output to extract a plausible score title.
  String? _cleanOcrTitle(String rawText) {
    // Take the first non-empty line that looks like a title.
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    for (final line in lines) {
      // Skip pure numbers (page numbers).
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      // Skip very short strings (noise).
      if (line.length < 3) continue;
      // Skip lines that are mostly non-alphabetic (notation artifacts).
      final alphaCount = line.runes.where((r) {
        final c = String.fromCharCode(r);
        return RegExp(r'[a-zA-Z]').hasMatch(c);
      }).length;
      if (alphaCount < line.length * 0.4) continue;
      // Clean up common OCR artifacts.
      return line
          .replaceAll(RegExp(r'[|_~]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return null;
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
        needsReview: !titlePages[i].matched,
      ));
    }
    return entries;
  }
}

class _TitlePage {
  const _TitlePage(this.title, this.page, {this.matched = false});
  final String title;
  final int page;
  final bool matched;
}

/// Classification result for a single page from the staff-line scan.
class _PageInfo {
  const _PageInfo(this.hasStaves, this.firstStaffFraction,
      [this.isScoreStart = false]);

  /// Whether this page contains music staff lines.
  final bool hasStaves;

  /// Fraction from the top where the first staff group starts (0.0–1.0).
  final double firstStaffFraction;

  /// True if this page is likely the start of a new score (title gap above
  /// first staff system).
  final bool isScoreStart;
}
