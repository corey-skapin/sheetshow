import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

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

      // Tier 4: Staff-line scan + OCR for scanned/handwritten pages
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

  // ─── Tier 4: Staff-line scan + OCR ────────────────────────────────────────

  /// Render width for the low-res staff-line detection pass.
  static const _scanWidth = 200;

  /// Minimum fraction of row pixels that must be dark to count as a
  /// horizontal line. Staff lines span most of the page width.
  static const _lineMinFill = 0.25;

  /// Dark pixel threshold (0-255). Pixel brightness below this = dark.
  static const _darkThreshold = 128;

  /// Minimum staff line groups (sets of ~5 lines) to classify a page as
  /// containing music notation.
  static const _minStaffGroups = 1;

  /// The fraction of page height from the top used for title detection.
  static const _scanTitleRegion = 0.22;

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

    // Find score boundary pages: a score page whose first staff system
    // starts significantly lower than the top (leaving room for a title).
    // Pages where staves start right at the top are continuation pages.
    final boundaryIndices = <int>[];
    for (int i = 0; i < totalPages; i++) {
      final info = pageInfos[i];
      if (!info.hasStaves) continue;
      if (info.isScoreStart) {
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
