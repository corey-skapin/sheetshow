import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/reader/models/annotation_layer.dart';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';

void main() {
  final now = DateTime(2024, 7, 1, 12, 0);

  InkStroke makeStroke({String id = 's1'}) => InkStroke(
        id: id,
        tool: AnnotationTool.pen,
        color: Colors.black,
        strokeWidth: 2.5,
        opacity: 1.0,
        points: const [NormalisedPoint(x: 0.1, y: 0.2)],
        createdAt: now,
      );

  AnnotationLayer makeLayer({
    String id = 'layer-1',
    String scoreId = 'score-1',
    int pageNumber = 1,
    List<InkStroke>? strokes,
  }) =>
      AnnotationLayer(
        id: id,
        scoreId: scoreId,
        pageNumber: pageNumber,
        strokes: strokes ?? [],
        updatedAt: now,
      );

  group('AnnotationLayer', () {
    test('constructs with required fields', () {
      final layer = makeLayer();
      expect(layer.id, 'layer-1');
      expect(layer.scoreId, 'score-1');
      expect(layer.pageNumber, 1);
      expect(layer.strokes, isEmpty);
    });

    group('strokesJson', () {
      test('returns empty JSON array for no strokes', () {
        final layer = makeLayer(strokes: []);
        expect(layer.strokesJson, '[]');
      });

      test('serializes strokes to JSON string', () {
        final layer = makeLayer(strokes: [makeStroke()]);
        final json = layer.strokesJson;
        expect(json, isNotEmpty);
        expect(json, startsWith('['));
        expect(json, endsWith(']'));
      });
    });

    group('fromDb', () {
      test('deserializes with empty strokesJson', () {
        final layer = AnnotationLayer.fromDb(
          id: 'layer-2',
          scoreId: 'score-2',
          pageNumber: 3,
          strokesJson: '[]',
          updatedAt: now,
        );
        expect(layer.id, 'layer-2');
        expect(layer.scoreId, 'score-2');
        expect(layer.pageNumber, 3);
        expect(layer.strokes, isEmpty);
      });

      test('deserializes strokes from JSON string', () {
        final stroke = makeStroke();
        final layer = makeLayer(strokes: [stroke]);
        final serialized = layer.strokesJson;

        final deserialized = AnnotationLayer.fromDb(
          id: 'layer-3',
          scoreId: 'score-1',
          pageNumber: 1,
          strokesJson: serialized,
          updatedAt: now,
        );
        expect(deserialized.strokes, hasLength(1));
        expect(deserialized.strokes.first.id, 's1');
      });

      test('handles null strokes JSON gracefully', () {
        final layer = AnnotationLayer.fromDb(
          id: 'layer-4',
          scoreId: 'score-1',
          pageNumber: 1,
          strokesJson: 'null',
          updatedAt: now,
        );
        expect(layer.strokes, isEmpty);
      });
    });

    group('copyWith', () {
      test('returns same values when no args provided', () {
        final layer = makeLayer(strokes: [makeStroke()]);
        final copy = layer.copyWith();
        expect(copy.id, layer.id);
        expect(copy.scoreId, layer.scoreId);
        expect(copy.pageNumber, layer.pageNumber);
        expect(copy.strokes, hasLength(1));
      });

      test('copies with new strokes', () {
        final layer = makeLayer();
        final copy = layer.copyWith(
          strokes: [makeStroke(), makeStroke(id: 's2')],
        );
        expect(copy.strokes, hasLength(2));
        expect(layer.strokes, isEmpty);
      });

      test('copies with new updatedAt', () {
        final layer = makeLayer();
        final newTime = DateTime(2025, 1, 1);
        final copy = layer.copyWith(updatedAt: newTime);
        expect(copy.updatedAt, newTime);
      });
    });
  });
}
