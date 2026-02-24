import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/models/enums.dart';

void main() {
  group('AnnotationTool', () {
    test('has expected values', () {
      expect(AnnotationTool.values, hasLength(3));
      expect(AnnotationTool.values, contains(AnnotationTool.pen));
      expect(AnnotationTool.values, contains(AnnotationTool.highlighter));
      expect(AnnotationTool.values, contains(AnnotationTool.eraser));
    });

    test('pen name', () {
      expect(AnnotationTool.pen.name, 'pen');
    });

    test('highlighter name', () {
      expect(AnnotationTool.highlighter.name, 'highlighter');
    });

    test('eraser name', () {
      expect(AnnotationTool.eraser.name, 'eraser');
    });
  });
}
