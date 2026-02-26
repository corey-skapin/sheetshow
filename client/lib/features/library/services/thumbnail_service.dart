import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// T037: ThumbnailService — renders page 1 of a PDF at 200x280 px, saves as PNG.

/// Generates and caches PDF thumbnails for the library grid view.
class ThumbnailService {
  ThumbnailService(this._scoreRepository);

  final ScoreRepository _scoreRepository;

  /// Generate a thumbnail for a specific page of the PDF (defaults to page 1).
  Future<String?> generateThumbnail(
    String localFilePath,
    String scoreId, {
    int pageIndex = 0,
  }) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final thumbDir = Directory(path.join(cacheDir.path, 'thumbnails'));
      await thumbDir.create(recursive: true);
      final thumbPath = path.join(thumbDir.path, '$scoreId.png');

      await _renderThumbnail((localFilePath, thumbPath, pageIndex));

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

/// Top-level function for isolate execution.
Future<void> _renderThumbnail((String, String, int) params) async {
  final (sourcePath, destPath, pageIndex) = params;
  final doc = await PdfDocument.openFile(sourcePath);
  if (doc.pages.isEmpty || pageIndex >= doc.pages.length) {
    await doc.dispose();
    return;
  }

  final page = doc.pages[pageIndex];
  const thumbWidth = 200.0;
  final scale = (thumbWidth / page.width).clamp(0.1, 4.0);

  final image = await page.render(
    width: (page.width * scale).round(),
    height: (page.height * scale).round(),
  );

  if (image == null) {
    await doc.dispose();
    return;
  }

  final uiImage = await image.createImage();
  final bytes = await uiImage.toByteData(format: ImageByteFormat.png);

  if (bytes != null) {
    await File(destPath).writeAsBytes(bytes.buffer.asUint8List());
  }

  await doc.dispose();
}

/// Riverpod provider for [ThumbnailService].
final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  return ThumbnailService(ref.watch(scoreRepositoryProvider));
});
