import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// T037: ThumbnailService — renders page 1 of a PDF at 200x280 px, saves as PNG.

/// Generates and caches PDF thumbnails for the library grid view.
///
/// Thumbnail generation is serialized via an internal queue so that large
/// batch imports (e.g. realbooks with 300+ scores) don't saturate the
/// event loop or block PDF rendering in the reader.
class ThumbnailService {
  ThumbnailService(this._scoreRepository);

  final ScoreRepository _scoreRepository;

  /// Internal queue of pending thumbnail jobs.
  final _queue = <_ThumbJob>[];
  bool _processing = false;

  /// Generate a thumbnail for a specific page of the PDF (defaults to page 1).
  ///
  /// The actual work is enqueued and processed sequentially. The returned
  /// Future completes when *this* thumbnail is done (or skipped on error).
  Future<String?> generateThumbnail(
    String localFilePath,
    String scoreId, {
    int pageIndex = 0,
  }) {
    final completer = Completer<String?>();
    _queue.add(_ThumbJob(
      localFilePath: localFilePath,
      scoreId: scoreId,
      pageIndex: pageIndex,
      completer: completer,
    ));
    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      try {
        final thumbPath = await _generateOne(
          job.localFilePath,
          job.scoreId,
          job.pageIndex,
        );
        job.completer.complete(thumbPath);
      } catch (e) {
        debugPrint('Thumbnail failed for ${job.scoreId}: $e');
        job.completer.complete(null);
      }
      // Yield to the event loop so the UI (and PDF viewer) stays responsive.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    _processing = false;
  }

  Future<String?> _generateOne(
    String localFilePath,
    String scoreId,
    int pageIndex,
  ) async {
    final cacheDir = await getApplicationCacheDirectory();
    final thumbDir = Directory(path.join(cacheDir.path, 'thumbnails'));
    await thumbDir.create(recursive: true);
    final thumbPath = path.join(thumbDir.path, '$scoreId.png');

    final doc = await PdfDocument.openFile(localFilePath);
    try {
      if (doc.pages.isEmpty || pageIndex >= doc.pages.length) return null;

      final page = doc.pages[pageIndex];
      const thumbWidth = 200.0;
      final scale = (thumbWidth / page.width).clamp(0.1, 4.0);

      final image = await page.render(
        width: (page.width * scale).round(),
        height: (page.height * scale).round(),
      );
      if (image == null) return null;

      final uiImage = await image.createImage();
      final bytes = await uiImage.toByteData(format: ImageByteFormat.png);
      if (bytes != null) {
        await File(thumbPath).writeAsBytes(bytes.buffer.asUint8List());
      }
    } finally {
      await doc.dispose();
    }

    // Update the score record with the thumbnail path.
    final score = await _scoreRepository.getById(scoreId);
    if (score != null) {
      await _scoreRepository.update(score.copyWith(thumbnailPath: thumbPath));
    }

    return thumbPath;
  }
}

class _ThumbJob {
  _ThumbJob({
    required this.localFilePath,
    required this.scoreId,
    required this.pageIndex,
    required this.completer,
  });
  final String localFilePath;
  final String scoreId;
  final int pageIndex;
  final Completer<String?> completer;
}

/// Riverpod provider for [ThumbnailService].
final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  return ThumbnailService(ref.watch(scoreRepositoryProvider));
});
