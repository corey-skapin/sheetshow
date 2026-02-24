import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../repositories/score_repository.dart';

// T037: ThumbnailService — renders page 1 of a PDF at 200x280 px, saves as PNG.

/// Generates and caches PDF thumbnails for the library grid view.
class ThumbnailService {
  ThumbnailService(this._scoreRepository);

  final ScoreRepository _scoreRepository;

  /// Generate a thumbnail for the first page of the PDF.
  /// Runs on an isolate to avoid blocking the UI thread.
  Future<String?> generateThumbnail(
    String localFilePath,
    String scoreId,
  ) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final thumbDir = Directory(path.join(cacheDir.path, 'thumbnails'));
      await thumbDir.create(recursive: true);
      final thumbPath = path.join(thumbDir.path, '$scoreId.png');

      // Render in an isolate to avoid blocking UI
      await compute(_renderThumbnail, _ThumbnailParams(localFilePath, thumbPath));

      // Update the score record with the thumbnail path
      final score = await _scoreRepository.getById(scoreId);
      if (score != null) {
        await _scoreRepository.update(score.copyWith(thumbnailPath: thumbPath));
      }

      return thumbPath;
    } catch (e) {
      // Thumbnail failure is non-fatal — library shows placeholder
      return null;
    }
  }
}

class _ThumbnailParams {
  const _ThumbnailParams(this.sourcePath, this.destPath);
  final String sourcePath;
  final String destPath;
}

/// Top-level function for isolate execution.
Future<void> _renderThumbnail(_ThumbnailParams params) async {
  final doc = await PdfDocument.openFile(params.sourcePath);
  if (doc.pages.isEmpty) {
    await doc.dispose();
    return;
  }

  final page = doc.pages.first;
  const thumbWidth = 200.0;
  const thumbHeight = 280.0;
  final scale = (thumbWidth / page.width).clamp(0.1, 4.0);

  final image = await page.render(
    width: (page.width * scale).round(),
    height: (page.height * scale).round(),
  );

  final bytes = await image.createImageIfNotAvailable()
      .then((img) => img.toByteData(format: ImageByteFormat.png));

  if (bytes != null) {
    await File(params.destPath)
        .writeAsBytes(bytes.buffer.asUint8List());
  }

  await doc.dispose();
}

/// Riverpod provider for [ThumbnailService].
final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  return ThumbnailService(ref.watch(scoreRepositoryProvider));
});
