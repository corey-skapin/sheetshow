import 'package:flutter/material.dart';
import 'package:sheetshow/core/models/enums.dart';

// T069: ToolSettings — immutable annotation tool configuration.

/// Immutable annotation tool configuration with per-tool defaults.
class ToolSettings {
  const ToolSettings({
    required this.activeTool,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
  });

  final AnnotationTool activeTool;
  final Color color;
  final double strokeWidth;
  final double opacity;

  /// Default settings for each tool.
  static const ToolSettings pen = ToolSettings(
    activeTool: AnnotationTool.pen,
    color: Color(0xFF1A1A2E),
    strokeWidth: 2.5,
    opacity: 1.0,
  );

  static const ToolSettings highlighter = ToolSettings(
    activeTool: AnnotationTool.highlighter,
    color: Color(0xFFFFEB3B),
    strokeWidth: 12.0,
    opacity: 0.4,
  );

  static const ToolSettings eraser = ToolSettings(
    activeTool: AnnotationTool.eraser,
    color: Color(0x00000000),
    strokeWidth: 20.0,
    opacity: 1.0,
  );

  ToolSettings copyWith({
    AnnotationTool? activeTool,
    Color? color,
    double? strokeWidth,
    double? opacity,
  }) =>
      ToolSettings(
        activeTool: activeTool ?? this.activeTool,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
      );
}
