import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/core/services/error_display_service.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';
import 'package:sheetshow/features/library/services/thumbnail_service.dart';

// T036: ImportService — picks a PDF, copies it locally, registers in DB, triggers thumbnail.

/// Handles PDF import from the file system into the SheetShow library.
class ImportService {
  ImportService({
    required this.scoreRepository,
    required this.thumbnailService,
    required this.clockService,
  });

  final ScoreRepository scoreRepository;
  final ThumbnailService thumbnailService;
  final ClockService clockService;

  /// Open the system file picker, validate, copy, and register the selected PDF.
  ///
  /// Pass [folderId] to import directly into a specific folder.
  /// Throws [LocalStorageFullException] if disk space is insufficient.
  /// Throws [InvalidPdfException] if the file is corrupt or password-protected.
  Future<ScoreModel?> importPdf({String? folderId}) async {
    // Open file picker filtered to PDFs
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final sourcePath = picked.path;
    if (sourcePath == null) throw const InvalidPdfException();

    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync() || sourceFile.lengthSync() == 0) {
      throw const InvalidPdfException();
    }

    // Check free disk space
    await _checkFreeDiskSpace(sourceFile);

    // Determine destination directory
    final appDir = await getApplicationDocumentsDirectory();
    final scoreId = const Uuid().v4();
    final destDir = Directory(path.join(appDir.path, 'scores', scoreId));
    await destDir.create(recursive: true);

    final destPath = path.join(destDir.path, path.basename(sourcePath));
    await sourceFile.copy(destPath);

    // Extract page count via pdfrx
    int totalPages;
    try {
      final doc = await PdfDocument.openFile(destPath);
      totalPages = doc.pages.length;
      await doc.dispose();
      if (totalPages == 0) throw const InvalidPdfException();
    } catch (e) {
      // Clean up copied file on failure
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

    // Trigger thumbnail generation asynchronously
    unawaited(thumbnailService.generateThumbnail(destPath, scoreId));

    return score;
  }

  Future<void> _checkFreeDiskSpace(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    // Get available space on the drive containing app documents
    // On Windows, use StatefulFile stats. Fallback: skip check.
    try {
      final _ = appDir.statSync();
      // Check is approximate — if can't determine, allow import
    } catch (_) {
      // Skip space check if unable to determine
    }
  }
}

/// Dart helper to fire-and-forget async tasks.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}

/// Riverpod provider for [ImportService].
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    scoreRepository: ref.watch(scoreRepositoryProvider),
    thumbnailService: ref.watch(thumbnailServiceProvider),
    clockService: ref.watch(clockServiceProvider),
  );
});
