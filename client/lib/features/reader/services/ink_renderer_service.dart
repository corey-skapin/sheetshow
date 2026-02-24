import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';
import 'package:sheetshow/features/reader/models/annotation_layer.dart';
import 'package:sheetshow/features/reader/models/tool_settings.dart';
import 'package:sheetshow/core/models/enums.dart';

// T072: InkRendererService — converts InkStroke list to Flutter Paths for CustomPainter.

/// Converts annotation strokes to Flutter Paint + Path objects for rendering.
class InkRendererService {
  /// Render all strokes in a [layer] scaled to [pageSize].
  List<StrokeRenderData> buildRenderData(
    AnnotationLayer layer,
    Size pageSize,
  ) {
    return layer.strokes
        .map((stroke) => _buildStrokeRender(stroke, pageSize))
        .toList();
  }

  StrokeRenderData _buildStrokeRender(InkStroke stroke, Size pageSize) {
    final path = Path();
    if (stroke.points.isEmpty) {
      return StrokeRenderData(path: path, paint: _buildPaint(stroke, 1.0));
    }

    final first = stroke.points.first;
    path.moveTo(
      first.x * pageSize.width,
      first.y * pageSize.height,
    );

    for (var i = 1; i < stroke.points.length; i++) {
      final p = stroke.points[i];
      final prev = stroke.points[i - 1];
      // Cubic smoothing between consecutive points
      final cx = (prev.x + p.x) / 2 * pageSize.width;
      final cy = (prev.y + p.y) / 2 * pageSize.height;
      path.quadraticBezierTo(
        prev.x * pageSize.width,
        prev.y * pageSize.height,
        cx,
        cy,
      );
    }

    final last = stroke.points.last;
    path.lineTo(last.x * pageSize.width, last.y * pageSize.height);

    // Modulate width by last point's pressure
    final pressure = stroke.points.isNotEmpty
        ? stroke.points.last.pressure.clamp(0.1, 1.0)
        : 1.0;

    return StrokeRenderData(
      path: path,
      paint: _buildPaint(stroke, pressure),
    );
  }

  Paint _buildPaint(InkStroke stroke, double pressure) {
    final paint = Paint()
      ..strokeWidth = stroke.strokeWidth * pressure
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.tool == AnnotationTool.eraser) {
      paint.blendMode = BlendMode.clear;
      paint.color = Colors.transparent;
    } else {
      paint.color = stroke.color.withOpacity(stroke.opacity);
    }

    return paint;
  }
}

/// Render data for a single stroke.
class StrokeRenderData {
  const StrokeRenderData({required this.path, required this.paint});
  final Path path;
  final Paint paint;
}
