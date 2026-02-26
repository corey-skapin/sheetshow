import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/clock_service.dart';
import 'package:sheetshow/features/reader/models/annotation_layer.dart';

/// Client-side annotation repository storing ink strokes per page.
class AnnotationRepository {
  AnnotationRepository(this._db, this._clock);

  final AppDatabase _db;
  final ClockService _clock;

  /// Get the annotation layer for a specific score page, or null if not exists.
  Future<AnnotationLayer?> getLayer(String scoreId, int pageNumber) async {
    final row = await (_db.select(_db.annotationLayers)
          ..where((a) =>
              a.scoreId.equals(scoreId) & a.pageNumber.equals(pageNumber)))
        .getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  /// Watch the annotation layer for a specific score page reactively.
  Stream<AnnotationLayer?> watchLayer(String scoreId, int pageNumber) {
    return (_db.select(_db.annotationLayers)
          ..where((a) =>
              a.scoreId.equals(scoreId) & a.pageNumber.equals(pageNumber)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _mapRow(row));
  }

  /// Upsert the annotation layer.
  Future<void> saveLayer(AnnotationLayer layer) async {
    final existing = await getLayer(layer.scoreId, layer.pageNumber);
    if (existing == null) {
      await _db.into(_db.annotationLayers).insert(
            AnnotationLayersCompanion.insert(
              id: layer.id,
              scoreId: layer.scoreId,
              pageNumber: layer.pageNumber,
              strokesJson: Value(layer.strokesJson),
              updatedAt: layer.updatedAt,
            ),
          );
    } else {
      await (_db.update(_db.annotationLayers)
            ..where((a) =>
                a.scoreId.equals(layer.scoreId) &
                a.pageNumber.equals(layer.pageNumber)))
          .write(AnnotationLayersCompanion(
        strokesJson: Value(layer.strokesJson),
        updatedAt: Value(layer.updatedAt),
      ));
    }
  }

  /// Clear all strokes for a page.
  Future<void> clearLayer(String scoreId, int pageNumber) async {
    await (_db.update(_db.annotationLayers)
          ..where((a) =>
              a.scoreId.equals(scoreId) & a.pageNumber.equals(pageNumber)))
        .write(AnnotationLayersCompanion(
      strokesJson: const Value('[]'),
      updatedAt: Value(_clock.now()),
    ));
  }

  AnnotationLayer _mapRow(AnnotationLayerRow row) => AnnotationLayer.fromDb(
        id: row.id,
        scoreId: row.scoreId,
        pageNumber: row.pageNumber,
        strokesJson: row.strokesJson,
        updatedAt: row.updatedAt,
      );
}

/// Riverpod provider for [AnnotationRepository].
final annotationRepositoryProvider = Provider<AnnotationRepository>((ref) {
  return AnnotationRepository(
    ref.watch(databaseProvider).requireValue,
    ref.watch(clockServiceProvider),
  );
});
