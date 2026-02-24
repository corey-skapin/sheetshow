import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sheetshow/core/models/enums.dart';

// T067: InkStroke — a single annotation stroke with normalised coordinates.

/// A single ink stroke drawn by the user.
/// Coordinates are normalised to [0,1] relative to page dimensions.
class NormalisedPoint {
  const NormalisedPoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });

  /// Normalised x position [0,1].
  final double x;

  /// Normalised y position [0,1].
  final double y;

  /// Pen pressure [0,1]; defaults to 0.5 for non-pressure input.
  final double pressure;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'p': pressure,
      };

  factory NormalisedPoint.fromJson(Map<String, dynamic> json) =>
      NormalisedPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
      );
}

/// A single ink stroke on a page.
class InkStroke {
  const InkStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.points,
    required this.createdAt,
  });

  final String id;
  final AnnotationTool tool;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final List<NormalisedPoint> points;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tool': tool.name,
        'color': color.value,
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'points': points.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory InkStroke.fromJson(Map<String, dynamic> json) => InkStroke(
        id: json['id'] as String,
        tool: AnnotationTool.values.firstWhere(
          (t) => t.name == json['tool'],
          orElse: () => AnnotationTool.pen,
        ),
        color: Color(json['color'] as int),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        opacity: (json['opacity'] as num).toDouble(),
        points: (json['points'] as List)
            .map((p) => NormalisedPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InkStroke && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
