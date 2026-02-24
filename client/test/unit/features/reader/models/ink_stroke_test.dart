import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';

void main() {
  final createdAt = DateTime(2024, 5, 20, 10, 0);

  NormalisedPoint makePoint({
    double x = 0.5,
    double y = 0.5,
    double pressure = 0.5,
  }) =>
      NormalisedPoint(x: x, y: y, pressure: pressure);

  InkStroke makeStroke({
    String id = 'stroke-1',
    AnnotationTool tool = AnnotationTool.pen,
    Color color = Colors.black,
    double strokeWidth = 2.5,
    double opacity = 1.0,
    List<NormalisedPoint>? points,
    DateTime? createdAt,
  }) =>
      InkStroke(
        id: id,
        tool: tool,
        color: color,
        strokeWidth: strokeWidth,
        opacity: opacity,
        points: points ?? [makePoint()],
        createdAt: createdAt ?? DateTime(2024, 5, 20, 10, 0),
      );

  group('NormalisedPoint', () {
    test('constructs with required fields', () {
      const p = NormalisedPoint(x: 0.1, y: 0.9, pressure: 0.7);
      expect(p.x, 0.1);
      expect(p.y, 0.9);
      expect(p.pressure, 0.7);
    });

    test('default pressure is 0.5', () {
      const p = NormalisedPoint(x: 0.2, y: 0.3);
      expect(p.pressure, 0.5);
    });

    group('toJson', () {
      test('serializes all fields', () {
        const p = NormalisedPoint(x: 0.25, y: 0.75, pressure: 0.8);
        final json = p.toJson();
        expect(json['x'], 0.25);
        expect(json['y'], 0.75);
        expect(json['p'], 0.8);
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = {'x': 0.25, 'y': 0.75, 'p': 0.8};
        final p = NormalisedPoint.fromJson(json);
        expect(p.x, 0.25);
        expect(p.y, 0.75);
        expect(p.pressure, 0.8);
      });

      test('defaults pressure to 0.5 when missing', () {
        final json = <String, dynamic>{'x': 0.1, 'y': 0.2};
        final p = NormalisedPoint.fromJson(json);
        expect(p.pressure, 0.5);
      });

      test('round-trips through toJson and fromJson', () {
        const original = NormalisedPoint(x: 0.3, y: 0.6, pressure: 0.9);
        final copy = NormalisedPoint.fromJson(original.toJson());
        expect(copy.x, original.x);
        expect(copy.y, original.y);
        expect(copy.pressure, original.pressure);
      });
    });
  });

  group('InkStroke', () {
    test('constructs with required fields', () {
      final stroke = makeStroke();
      expect(stroke.id, 'stroke-1');
      expect(stroke.tool, AnnotationTool.pen);
      expect(stroke.strokeWidth, 2.5);
      expect(stroke.opacity, 1.0);
    });

    group('equality', () {
      test('equal when same id', () {
        final a = makeStroke(id: 'stroke-1');
        final b = makeStroke(id: 'stroke-1', strokeWidth: 10.0);
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        final a = makeStroke(id: 'stroke-1');
        final b = makeStroke(id: 'stroke-2');
        expect(a, isNot(equals(b)));
      });

      test('hashCode based on id', () {
        final a = makeStroke(id: 'stroke-1');
        final b = makeStroke(id: 'stroke-1');
        expect(a.hashCode, b.hashCode);
      });

      test('identical is equal', () {
        final a = makeStroke();
        expect(a, equals(a));
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final stroke = makeStroke(
          id: 's1',
          tool: AnnotationTool.highlighter,
          color: const Color(0xFFFF0000),
          strokeWidth: 5.0,
          opacity: 0.5,
          createdAt: createdAt,
        );
        final json = stroke.toJson();
        expect(json['id'], 's1');
        expect(json['tool'], 'highlighter');
        expect(json['color'], const Color(0xFFFF0000).value);
        expect(json['strokeWidth'], 5.0);
        expect(json['opacity'], 0.5);
        expect(json['points'], isA<List>());
        expect(json['createdAt'], createdAt.toIso8601String());
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = {
          'id': 's2',
          'tool': 'pen',
          'color': Colors.blue.value,
          'strokeWidth': 3.0,
          'opacity': 0.8,
          'points': [
            {'x': 0.1, 'y': 0.2, 'p': 0.6},
          ],
          'createdAt': createdAt.toIso8601String(),
        };
        final stroke = InkStroke.fromJson(json);
        expect(stroke.id, 's2');
        expect(stroke.tool, AnnotationTool.pen);
        expect(stroke.color, const Color(0xff2196f3));
        expect(stroke.strokeWidth, 3.0);
        expect(stroke.opacity, 0.8);
        expect(stroke.points, hasLength(1));
        expect(stroke.points.first.x, 0.1);
      });

      test('falls back to pen for unknown tool', () {
        final json = {
          'id': 's3',
          'tool': 'unknown_tool',
          'color': 0xFF000000,
          'strokeWidth': 2.0,
          'opacity': 1.0,
          'points': <dynamic>[],
          'createdAt': createdAt.toIso8601String(),
        };
        final stroke = InkStroke.fromJson(json);
        expect(stroke.tool, AnnotationTool.pen);
      });

      test('falls back to now on invalid date', () {
        final before = DateTime.now();
        final json = {
          'id': 's4',
          'tool': 'eraser',
          'color': 0xFF000000,
          'strokeWidth': 2.0,
          'opacity': 1.0,
          'points': <dynamic>[],
          'createdAt': 'not-a-date',
        };
        final stroke = InkStroke.fromJson(json);
        final after = DateTime.now();
        expect(
          stroke.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          stroke.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('round-trips through toJson and fromJson', () {
        final original = makeStroke(
          id: 'rt-1',
          tool: AnnotationTool.eraser,
          createdAt: createdAt,
          points: [
            const NormalisedPoint(x: 0.1, y: 0.2, pressure: 0.3),
          ],
        );
        final copy = InkStroke.fromJson(original.toJson());
        expect(copy.id, original.id);
        expect(copy.tool, original.tool);
        expect(copy.strokeWidth, original.strokeWidth);
        expect(copy.points, hasLength(1));
      });
    });
  });
}
