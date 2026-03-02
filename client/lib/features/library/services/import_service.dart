import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/error_display_service.dart';
import 'package:sheetshow/features/library/models/realbook_model.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/folder_repository.dart';
import 'package:sheetshow/features/library/repositories/realbook_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/library/services/realbook_indexing_service.dart';
import 'package:sheetshow/features/library/services/thumbnail_service.dart';

// T036: ImportService — picks PDFs or a folder, registers in DB in-place, triggers thumbnail.

/// Resolves the path to the SheetShowOcr.exe tool bundled alongside the app.
String _resolveOcrExePath() {
  // In a Flutter Windows app, the exe is in the same directory as the runner.
  // During development, check the build output directory.
  final exeDir = path.dirname(Platform.resolvedExecutable);
  final candidates = [
    path.join(exeDir, 'SheetShowOcr.exe'),
    path.join(exeDir, 'ocr', 'SheetShowOcr.exe'),
  ];
  for (final p in candidates) {
    if (File(p).existsSync()) return p;
  }
  // Fallback: try running via dotnet from source tree.
  return 'SheetShowOcr.exe';
}

/// A simple cancellation token. Call [cancel] to request cancellation;
/// check [isCancelled] inside loops.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Handles PDF import from the file system into the SheetShow library.
///
/// Scores are referenced **in-place** — no file copying occurs.
class ImportService {
  ImportService({
    required this.scoreRepository,
    required this.folderRepository,
    required this.thumbnailService,
    required this.clockService,
    required this.realbookRepository,
    required this.indexingService,
  });

  final ScoreRepository scoreRepository;
  final FolderRepository folderRepository;
  final ThumbnailService thumbnailService;
  final ClockService clockService;
  final RealbookRepository realbookRepository;
  final RealbookIndexingService indexingService;

  /// Open the system file picker (multi-select), validate, and register
  /// each selected PDF in-place.
  ///
  /// [onProgress] is called after each successful import with (done, total).
  /// [cancelToken] can be used to stop after the current file finishes.
  Future<List<ScoreModel>> importFiles({
    String? folderId,
    void Function(int done, int total)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return [];

    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    return _importPaths(
      paths,
      folderId: folderId,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// Open a directory picker. Creates a new app folder named after the chosen
  /// directory (nested under [parentFolderId] if provided), then recursively
  /// imports all PDFs — preserving sub-directory structure as nested app folders.
  ///
  /// [onProgress] is called after each successful import with (done, total).
  /// [cancelToken] can be used to stop after the current file finishes.
  Future<List<ScoreModel>> importFolder({
    String? parentFolderId,
    void Function(int done, int total)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return [];

    // Count total PDFs across all subdirectories for accurate progress.
    final allPdfPaths = await compute(_scanForPdfs, dirPath);
    if (allPdfPaths.isEmpty) return [];

    final total = allPdfPaths.length;
    final done = _Counter();

    // Create root app folder named after the chosen directory.
    final rootFolder = FolderModel(
      id: const Uuid().v4(),
      name: path.basename(dirPath),
      parentFolderId: parentFolderId,
      createdAt: clockService.now(),
      updatedAt: clockService.now(),
      diskPath: dirPath,
    );
    await folderRepository.create(rootFolder);

    return _importDirRecursive(
      dirPath,
      rootFolder.id,
      cancelToken,
      onProgress,
      done,
      total,
    );
  }

  /// Open the system file picker for a single PDF, auto-index it as a realbook,
  /// and create score entries for each detected section.
  ///
  /// [onProgress] is called with (currentPage, totalPages) during indexing.
  Future<RealbookModel?> importRealbook({
    int pageOffset = 0,
    void Function(int done, int total)? onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final pdfPath = result.files.first.path;
    if (pdfPath == null) return null;

    final sourceFile = File(pdfPath);
    if (!await sourceFile.exists() || await sourceFile.length() == 0) {
      throw const InvalidPdfException();
    }

    int totalPages;
    try {
      final doc = await PdfDocument.openFile(pdfPath);
      totalPages = doc.pages.length;
      await doc.dispose();
      if (totalPages == 0) throw const InvalidPdfException();
    } catch (e) {
      debugPrint('ImportService: PdfDocument.openFile failed for '
          '"$pdfPath": $e');
      // Fallback: count pages by scanning the file for /Type /Page entries.
      totalPages = await _countPagesFromBytes(sourceFile);
      if (totalPages <= 0) {
        throw const InvalidPdfException();
      }
      debugPrint('ImportService: Fallback page count: $totalPages');
    }

    final realbookId = const Uuid().v4();
    final now = clockService.now();
    final filename = path.basename(pdfPath);
    final title = path.basenameWithoutExtension(pdfPath);

    final realbook = RealbookModel(
      id: realbookId,
      title: title,
      filename: filename,
      localFilePath: pdfPath,
      totalPages: totalPages,
      pageOffset: pageOffset,
      updatedAt: now,
    );
    await realbookRepository.insert(realbook);

    // Auto-index the realbook.
    final entries = await indexingService.indexRealbook(
      pdfPath,
      pageOffset: pageOffset,
      onProgress: onProgress,
    );

    // Create score entries for each detected section.
    int reviewCount = 0;
    for (final entry in entries) {
      final scoreId = const Uuid().v4();
      if (entry.needsReview) reviewCount++;
      final score = ScoreModel(
        id: scoreId,
        title: entry.title,
        filename: filename,
        localFilePath: pdfPath,
        totalPages: entry.endPage - entry.startPage + 1,
        updatedAt: now,
        realbookId: realbookId,
        startPage: entry.startPage,
        endPage: entry.endPage,
        realbookTitle: title,
        needsReview: entry.needsReview,
      );
      await scoreRepository.insert(score);
      // Generate thumbnail from the excerpt's first page (0-indexed).
      unawaited(thumbnailService.generateThumbnail(
        pdfPath,
        scoreId,
        pageIndex: entry.startPage - 1,
      ));
    }

    if (reviewCount > 0) {
      debugPrint('ImportService: $reviewCount scores flagged for review '
          '(unindexed page ranges)');
    }

    return realbook.copyWith(scoreCount: entries.length);
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  /// Recursively import a directory: imports PDFs directly inside [dirPath]
  /// into [parentFolderId], then creates a child app folder for each
  /// subdirectory and recurses into it.
  Future<List<ScoreModel>> _importDirRecursive(
    String dirPath,
    String? parentFolderId,
    CancellationToken? cancelToken,
    void Function(int done, int total)? onProgress,
    _Counter done,
    int total,
  ) async {
    final results = <ScoreModel>[];

    final entries = await Directory(dirPath).list().toList();
    final pdfs = entries
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();
    final subdirs = entries.whereType<Directory>().toList();

    // Import PDFs in this directory.
    for (final pdfFile in pdfs) {
      if (cancelToken?.isCancelled == true) return results;
      try {
        final score =
            await _importSingleFile(pdfFile.path, folderId: parentFolderId);
        if (score != null) {
          results.add(score);
          done.value++;
          onProgress?.call(done.value, total);
        }
      } catch (e, st) {
        debugPrint('Import failed for ${pdfFile.path}: $e\n$st');
        done.value++;
        onProgress?.call(done.value, total);
      }
    }

    // Recurse into subdirectories.
    for (final subdir in subdirs) {
      if (cancelToken?.isCancelled == true) return results;
      try {
        final subFolder = FolderModel(
          id: const Uuid().v4(),
          name: path.basename(subdir.path),
          parentFolderId: parentFolderId,
          createdAt: clockService.now(),
          updatedAt: clockService.now(),
          diskPath: subdir.path,
        );
        await folderRepository.create(subFolder);
        final subResults = await _importDirRecursive(
          subdir.path,
          subFolder.id,
          cancelToken,
          onProgress,
          done,
          total,
        );
        results.addAll(subResults);
      } catch (e, st) {
        debugPrint('Folder import failed for ${subdir.path}: $e\n$st');
      }
    }

    return results;
  }

  Future<List<ScoreModel>> _importPaths(
    List<String> paths, {
    String? folderId,
    void Function(int done, int total)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final results = <ScoreModel>[];
    final total = paths.length;
    for (final sourcePath in paths) {
      if (cancelToken?.isCancelled == true) break;
      try {
        final score = await _importSingleFile(sourcePath, folderId: folderId);
        if (score != null) {
          results.add(score);
          onProgress?.call(results.length, total);
        }
      } catch (e, st) {
        debugPrint('Import failed for $sourcePath: $e\n$st');
      }
    }
    return results;
  }

  /// Register a single PDF file in-place. Returns null if the file is invalid.
  ///
  /// Scores are **not copied** — [ScoreModel.localFilePath] points directly to
  /// [sourcePath] in the workspace.
  ///
  /// If a score with the same filename already exists, adds a folder membership
  /// to the existing score instead of creating a duplicate.
  Future<ScoreModel?> _importSingleFile(
    String sourcePath, {
    String? folderId,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists() || await sourceFile.length() == 0) {
      throw const InvalidPdfException();
    }

    final filename = path.basename(sourcePath);

    // Deduplicate: if this filename was already imported, reuse the existing
    // score (same annotations, tags, etc.) and just add a folder membership.
    final existing = await scoreRepository.getByFilename(filename);
    if (existing != null) {
      if (folderId != null) {
        await scoreRepository.addToFolder(existing.id, folderId);
      }
      return existing;
    }

    int totalPages;
    try {
      final doc = await PdfDocument.openFile(sourcePath);
      totalPages = doc.pages.length;
      await doc.dispose();
      if (totalPages == 0) throw const InvalidPdfException();
    } catch (e) {
      debugPrint('ImportService: PdfDocument.openFile failed for '
          '"$sourcePath": $e');
      final sourceFile = File(sourcePath);
      totalPages = await _countPagesFromBytes(sourceFile);
      if (totalPages <= 0) {
        throw const InvalidPdfException();
      }
      debugPrint('ImportService: Fallback page count: $totalPages');
    }

    final scoreId = const Uuid().v4();
    final now = clockService.now();
    final title = path.basenameWithoutExtension(sourcePath);

    final score = ScoreModel(
      id: scoreId,
      title: title,
      filename: filename,
      localFilePath: sourcePath,
      totalPages: totalPages,
      updatedAt: now,
    );

    await scoreRepository.insert(score, folderId: folderId);
    unawaited(thumbnailService.generateThumbnail(sourcePath, scoreId));

    return score;
  }

  /// Fallback page count: scan PDF bytes for page object markers.
  /// Used when pdfium (pdfrx) can't open the file.
  static Future<int> _countPagesFromBytes(File file) async {
    try {
      final bytes = await file.readAsBytes();
      // Search for /Type /Page entries (not /Type /Pages which is the
      // page tree node). Uses ASCII-only matching on raw bytes.
      final typeBytes = '/Type'.codeUnits;
      final pageBytes = '/Page'.codeUnits;
      int count = 0;
      for (int i = 0; i < bytes.length - 12; i++) {
        if (_bytesMatch(bytes, i, typeBytes)) {
          // Skip whitespace after /Type
          int j = i + typeBytes.length;
          while (j < bytes.length &&
              (bytes[j] == 32 ||
                  bytes[j] == 10 ||
                  bytes[j] == 13 ||
                  bytes[j] == 9)) {
            j++;
          }
          if (j < bytes.length - 5 && _bytesMatch(bytes, j, pageBytes)) {
            // Make sure it's /Page and not /Pages
            final afterPage = j + pageBytes.length;
            if (afterPage < bytes.length && bytes[afterPage] != 0x73) {
              // 0x73 = 's'
              count++;
            }
          }
        }
      }
      return count;
    } catch (e) {
      debugPrint('ImportService: _countPagesFromBytes failed: $e');
      return 0;
    }
  }

  static bool _bytesMatch(List<int> data, int offset, List<int> pattern) {
    if (offset + pattern.length > data.length) return false;
    for (int i = 0; i < pattern.length; i++) {
      if (data[offset + i] != pattern[i]) return false;
    }
    return true;
  }
}

/// Mutable counter threaded through recursive import to track progress.
class _Counter {
  int value = 0;
}

/// Top-level function for use with [compute] — scans [dirPath] for PDF files
/// in a background isolate so the UI thread is never blocked.
List<String> _scanForPdfs(String dirPath) {
  return Directory(dirPath)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.pdf'))
      .map((f) => f.path)
      .toList();
}

/// Dart helper to fire-and-forget async tasks.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}

/// Riverpod provider for [ImportService].
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    scoreRepository: ref.watch(scoreRepositoryProvider),
    folderRepository: ref.watch(folderRepositoryProvider),
    thumbnailService: ref.watch(thumbnailServiceProvider),
    clockService: ref.watch(clockServiceProvider),
    realbookRepository: ref.watch(realbookRepositoryProvider),
    indexingService: RealbookIndexingService(ocrExePath: _resolveOcrExePath()),
  );
});
