import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/reader/models/tool_settings.dart';

void main() {
  group('ToolSettings', () {
    test('pen static default has expected values', () {
      expect(ToolSettings.pen.activeTool, AnnotationTool.pen);
      expect(ToolSettings.pen.strokeWidth, 2.5);
      expect(ToolSettings.pen.opacity, 1.0);
    });

    test('highlighter static default has expected values', () {
      expect(ToolSettings.highlighter.activeTool, AnnotationTool.highlighter);
      expect(ToolSettings.highlighter.strokeWidth, 12.0);
      expect(ToolSettings.highlighter.opacity, 0.4);
    });

    test('eraser static default has expected values', () {
      expect(ToolSettings.eraser.activeTool, AnnotationTool.eraser);
      expect(ToolSettings.eraser.strokeWidth, 20.0);
      expect(ToolSettings.eraser.opacity, 1.0);
    });

    test('constructs with custom values', () {
      const settings = ToolSettings(
        activeTool: AnnotationTool.pen,
        color: Colors.red,
        strokeWidth: 5.0,
        opacity: 0.7,
      );
      expect(settings.activeTool, AnnotationTool.pen);
      expect(settings.color, Colors.red);
      expect(settings.strokeWidth, 5.0);
      expect(settings.opacity, 0.7);
    });

    group('copyWith', () {
      test('returns same values when no args provided', () {
        const original = ToolSettings(
          activeTool: AnnotationTool.pen,
          color: Colors.black,
          strokeWidth: 2.5,
          opacity: 1.0,
        );
        final copy = original.copyWith();
        expect(copy.activeTool, original.activeTool);
        expect(copy.color, original.color);
        expect(copy.strokeWidth, original.strokeWidth);
        expect(copy.opacity, original.opacity);
      });

      test('copies with new activeTool', () {
        final copy =
            ToolSettings.pen.copyWith(activeTool: AnnotationTool.eraser);
        expect(copy.activeTool, AnnotationTool.eraser);
        expect(copy.strokeWidth, ToolSettings.pen.strokeWidth);
      });

      test('copies with new color', () {
        final copy = ToolSettings.pen.copyWith(color: Colors.blue);
        expect(copy.color, Colors.blue);
      });

      test('copies with new strokeWidth', () {
        final copy = ToolSettings.pen.copyWith(strokeWidth: 8.0);
        expect(copy.strokeWidth, 8.0);
      });

      test('copies with new opacity', () {
        final copy = ToolSettings.highlighter.copyWith(opacity: 0.6);
        expect(copy.opacity, 0.6);
        expect(copy.activeTool, AnnotationTool.highlighter);
      });
    });
  });
}
