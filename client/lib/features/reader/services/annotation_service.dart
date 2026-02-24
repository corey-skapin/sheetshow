import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';
import 'package:sheetshow/features/reader/models/annotation_layer.dart';
import 'package:sheetshow/features/reader/repositories/annotation_repository.dart';

// T071: AnnotationService — in-memory stroke management with persistence.

/// Key used to scope an [AnnotationService] to a specific score page.
typedef AnnotationPageKey = ({String scoreId, int pageNumber});

/// Manages the annotation state for a single page: add, undo, clear.
class AnnotationService extends StateNotifier<AnnotationLayer?> {
  AnnotationService(this._repo, this._scoreId, this._pageNumber) : super(null) {
    _loadPage();
  }

  final AnnotationRepository _repo;
  final String _scoreId;
  final int _pageNumber;

  Future<void> _loadPage() async {
    final layer = await _repo.getLayer(_scoreId, _pageNumber);
    if (mounted) state = layer;
  }

  /// Add a stroke to the current page.
  Future<void> addStroke(InkStroke stroke) async {
    final current = state;
    final strokes = <InkStroke>[...(current?.strokes ?? []), stroke];
    final updated = _updateLayer(current, strokes);
    state = updated;
    await _persist(updated);
  }

  /// Undo the last added stroke.
  Future<void> undoLastStroke() async {
    final current = state;
    if (current == null || current.strokes.isEmpty) return;
    final strokes = List<InkStroke>.from(current.strokes)..removeLast();
    final updated = _updateLayer(current, strokes);
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
  ) {
    final now = DateTime.now();
    if (current == null) {
      return AnnotationLayer(
        id: const Uuid().v4(),
        scoreId: _scoreId,
        pageNumber: _pageNumber,
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

/// Riverpod provider for [AnnotationService] — scoped per score page.
final annotationServiceProvider = StateNotifierProvider.autoDispose
    .family<AnnotationService, AnnotationLayer?, AnnotationPageKey>(
  (ref, key) => AnnotationService(
    ref.watch(annotationRepositoryProvider),
    key.scoreId,
    key.pageNumber,
  ),
);
