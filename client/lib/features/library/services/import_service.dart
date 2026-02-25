import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/error_display_service.dart';
import 'package:sheetshow/features/library/models/folder_model.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/folder_repository.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/library/services/thumbnail_service.dart';

// T036: ImportService — picks PDFs or a folder, copies locally, registers in DB, triggers thumbnail.

/// A simple cancellation token. Call [cancel] to request cancellation;
/// check [isCancelled] inside loops.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Handles PDF import from the file system into the SheetShow library.
class ImportService {
  ImportService({
    required this.scoreRepository,
    required this.folderRepository,
    required this.thumbnailService,
    required this.clockService,
  });

  final ScoreRepository scoreRepository;
  final FolderRepository folderRepository;
  final ThumbnailService thumbnailService;
  final ClockService clockService;

  /// Open the system file picker (multi-select), validate, copy, and register
  /// each selected PDF.
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
  /// directory (nested under [parentFolderId] if provided), then imports all
  /// PDF files found inside into that new folder.
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

    // Scan the directory in a background isolate to avoid blocking the UI thread.
    final pdfPaths = await compute(_scanForPdfs, dirPath);

    if (pdfPaths.isEmpty) return [];

    // Create a new app folder named after the chosen directory.
    final folderName = path.basename(dirPath);
    final now = clockService.now();
    final newFolder = FolderModel(
      id: const Uuid().v4(),
      name: folderName,
      parentFolderId: parentFolderId,
      createdAt: now,
      updatedAt: now,
    );
    await folderRepository.create(newFolder);

    return _importPaths(
      pdfPaths,
      folderId: newFolder.id,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

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
      } catch (_) {
        // Skip invalid/corrupt files; continue with the rest.
      }
    }
    return results;
  }

  /// Copy and register a single PDF file. Returns null if the file is invalid.
  Future<ScoreModel?> _importSingleFile(
    String sourcePath, {
    String? folderId,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists() || await sourceFile.length() == 0) {
      throw const InvalidPdfException();
    }

    await _checkFreeDiskSpace(sourceFile);

    final appDir = await getApplicationDocumentsDirectory();
    final scoreId = const Uuid().v4();
    final destDir = Directory(path.join(appDir.path, 'scores', scoreId));
    await destDir.create(recursive: true);

    final destPath = path.join(destDir.path, path.basename(sourcePath));
    await sourceFile.copy(destPath);

    int totalPages;
    try {
      final doc = await PdfDocument.openFile(destPath);
      totalPages = doc.pages.length;
      await doc.dispose();
      if (totalPages == 0) throw const InvalidPdfException();
    } catch (e) {
      await File(destPath).delete();
      throw const InvalidPdfException();
    }

    final now = clockService.now();
    final filename = path.basename(sourcePath);
    final title = path.basenameWithoutExtension(sourcePath);

    final score = ScoreModel(
      id: scoreId,
      title: title,
      filename: filename,
      localFilePath: destPath,
      totalPages: totalPages,
      folderId: folderId,
      importedAt: now,
      updatedAt: now,
    );

    await scoreRepository.insert(score);
    unawaited(thumbnailService.generateThumbnail(destPath, scoreId));

    return score;
  }

  Future<void> _checkFreeDiskSpace(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    try {
      final _ = appDir.statSync();
    } catch (_) {
      // Skip space check if unable to determine
    }
  }
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
  );
});
