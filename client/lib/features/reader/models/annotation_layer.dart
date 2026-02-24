import 'dart:convert';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';

// T068: AnnotationLayer — stores all ink strokes for a single page of a score.

/// All annotation strokes for one page of a score.
class AnnotationLayer {
  const AnnotationLayer({
    required this.id,
    required this.scoreId,
    required this.pageNumber,
    required this.strokes,
    required this.updatedAt,
  });

  final String id;
  final String scoreId;
  final int pageNumber;
  final List<InkStroke> strokes;
  final DateTime updatedAt;

  /// Serialize strokes to JSON string for Drift storage.
  String get strokesJson => jsonEncode(strokes.map((s) => s.toJson()).toList());

  /// Create from Drift row.
  factory AnnotationLayer.fromDb({
    required String id,
    required String scoreId,
    required int pageNumber,
    required String strokesJson,
    required DateTime updatedAt,
  }) {
    final strokesRaw = jsonDecode(strokesJson) as List? ?? [];
    final strokes = strokesRaw
        .map((e) => InkStroke.fromJson(e as Map<String, dynamic>))
        .toList();
    return AnnotationLayer(
      id: id,
      scoreId: scoreId,
      pageNumber: pageNumber,
      strokes: strokes,
      updatedAt: updatedAt,
    );
  }

  AnnotationLayer copyWith({
    List<InkStroke>? strokes,
    DateTime? updatedAt,
  }) =>
      AnnotationLayer(
        id: id,
        scoreId: scoreId,
        pageNumber: pageNumber,
        strokes: strokes ?? this.strokes,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
