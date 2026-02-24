import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/constants/app_constants.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/reader/models/annotation_layer.dart';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';
import 'package:sheetshow/features/reader/models/tool_settings.dart';
import 'package:sheetshow/features/reader/repositories/annotation_repository.dart';

// T071: AnnotationService — in-memory stroke management with persistence.

/// Manages the annotation state for a single page: add, undo, clear.
class AnnotationService extends StateNotifier<AnnotationLayer?> {
  AnnotationService(this._repo) : super(null);

  final AnnotationRepository _repo;
  final List<InkStroke> _undoStack = [];

  /// Load annotations for a page.
  Future<void> loadPage(String scoreId, int pageNumber) async {
    final layer = await _repo.getLayer(scoreId, pageNumber);
    state = layer;
  }

  /// Add a stroke to the current page.
  Future<void> addStroke(InkStroke stroke) async {
    final current = state;
    final strokes = [...(current?.strokes ?? []), stroke];
    final updated = _updateLayer(current, strokes, stroke.id);
    state = updated;
    await _persist(updated);
  }

  /// Undo the last added stroke.
  Future<void> undoLastStroke() async {
    final current = state;
    if (current == null || current.strokes.isEmpty) return;
    final strokes = List<InkStroke>.from(current.strokes)..removeLast();
    final updated = _updateLayer(current, strokes, null);
    state = updated;
    await _persist(updated);
  }

  /// Clear all strokes for the current page.
  Future<void> clearAll() async {
    final current = state;
    if (current == null) return;
    final updated = current.copyWith(
      strokes: [],
      syncState: SyncState.pendingUpdate,
      updatedAt: DateTime.now(),
    );
    state = updated;
    await _persist(updated);
  }

  AnnotationLayer _updateLayer(
    AnnotationLayer? current,
    List<InkStroke> strokes,
    String? _,
  ) {
    final now = DateTime.now();
    if (current == null) {
      return AnnotationLayer(
        id: const Uuid().v4(),
        scoreId: '',
        pageNumber: 0,
        strokes: strokes,
        updatedAt: now,
        syncState: SyncState.pendingUpdate,
      );
    }
    return current.copyWith(
      strokes: strokes,
      syncState: SyncState.pendingUpdate,
      updatedAt: now,
    );
  }

  Future<void> _persist(AnnotationLayer layer) async {
    await _repo.saveLayer(layer);
  }
}

/// Riverpod provider for [AnnotationService] — scoped per page.
final annotationServiceProvider =
    StateNotifierProvider.autoDispose<AnnotationService, AnnotationLayer?>(
  (ref) => AnnotationService(ref.watch(annotationRepositoryProvider)),
);
