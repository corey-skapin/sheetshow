import 'dart:convert';
import '../../../core/models/enums.dart';
import 'ink_stroke.dart';

// T068: AnnotationLayer — stores all ink strokes for a single page of a score.

/// All annotation strokes for one page of a score.
class AnnotationLayer {
  const AnnotationLayer({
    required this.id,
    required this.scoreId,
    required this.pageNumber,
    required this.strokes,
    required this.updatedAt,
    this.syncState = SyncState.synced,
    this.serverVersion = 0,
  });

  final String id;
  final String scoreId;
  final int pageNumber;
  final List<InkStroke> strokes;
  final DateTime updatedAt;
  final SyncState syncState;
  final int serverVersion;

  /// Serialize strokes to JSON string for Drift storage.
  String get strokesJson =>
      jsonEncode(strokes.map((s) => s.toJson()).toList());

  /// Create from Drift row.
  factory AnnotationLayer.fromDb({
    required String id,
    required String scoreId,
    required int pageNumber,
    required String strokesJson,
    required DateTime updatedAt,
    required SyncState syncState,
    required int serverVersion,
  }) {
    final strokesRaw =
        jsonDecode(strokesJson) as List? ?? [];
    final strokes = strokesRaw
        .map((e) => InkStroke.fromJson(e as Map<String, dynamic>))
        .toList();
    return AnnotationLayer(
      id: id,
      scoreId: scoreId,
      pageNumber: pageNumber,
      strokes: strokes,
      updatedAt: updatedAt,
      syncState: syncState,
      serverVersion: serverVersion,
    );
  }

  AnnotationLayer copyWith({
    List<InkStroke>? strokes,
    SyncState? syncState,
    DateTime? updatedAt,
  }) =>
      AnnotationLayer(
        id: id,
        scoreId: scoreId,
        pageNumber: pageNumber,
        strokes: strokes ?? this.strokes,
        updatedAt: updatedAt ?? this.updatedAt,
        syncState: syncState ?? this.syncState,
        serverVersion: serverVersion,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scoreId': scoreId,
        'pageNumber': pageNumber,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'serverVersion': serverVersion,
      };
}
