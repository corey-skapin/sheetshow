import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/reader/models/annotation_layer.dart';
import 'package:sheetshow/features/reader/models/ink_stroke.dart';
import 'package:sheetshow/features/reader/models/tool_settings.dart';
import 'package:sheetshow/features/reader/services/annotation_service.dart';
import 'package:sheetshow/features/reader/services/ink_renderer_service.dart';

// T073: AnnotationOverlay — CustomPaint widget for real-time ink rendering.

/// Current tool settings provider.
final toolSettingsProvider = StateProvider<ToolSettings>(
  (_) => ToolSettings.pen,
);

/// Renders existing annotation strokes and captures new ink input.
///
/// When [editMode] is false the overlay is read-only: it draws saved strokes
/// but lets all pointer events pass through to the document viewer below.
class AnnotationOverlay extends ConsumerStatefulWidget {
  const AnnotationOverlay({
    super.key,
    required this.scoreId,
    required this.pageNumber,
    this.editMode = false,
  });

  final String scoreId;
  final int pageNumber;

  /// When false, pointer events are ignored so scroll/zoom work normally.
  final bool editMode;

  @override
  ConsumerState<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends ConsumerState<AnnotationOverlay> {
  final InkRendererService _renderer = InkRendererService();
  List<NormalisedPoint> _currentStrokePoints = [];
  Size _pageSize = Size.zero;

  AnnotationPageKey get _pageKey =>
      (scoreId: widget.scoreId, pageNumber: widget.pageNumber);

  @override
  Widget build(BuildContext context) {
    final layer = ref.watch(annotationServiceProvider(_pageKey));
    final toolSettings = ref.watch(toolSettingsProvider);

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        _pageSize = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          painter: _AnnotationPainter(
            layer: layer,
            currentPoints: _currentStrokePoints,
            renderer: _renderer,
            pageSize: _pageSize,
            currentTool: toolSettings,
          ),
          child: const SizedBox.expand(),
        );
      },
    );

    if (!widget.editMode) {
      // Pass all pointer events through to the document viewer.
      return IgnorePointer(child: content);
    }

    return Listener(
      onPointerDown: (event) => _handlePointerDown(event, toolSettings),
      onPointerMove: (event) => _handlePointerMove(event, toolSettings),
      onPointerUp: (event) => _handlePointerUp(event, toolSettings),
      child: content,
    );
  }

  void _handlePointerDown(PointerDownEvent event, ToolSettings settings) {
    if (_pageSize == Size.zero) return;
    setState(() {
      _currentStrokePoints = [
        NormalisedPoint(
          x: event.localPosition.dx / _pageSize.width,
          y: event.localPosition.dy / _pageSize.height,
          pressure: event.pressure.clamp(0.0, 1.0),
        ),
      ];
    });
  }

  void _handlePointerMove(PointerMoveEvent event, ToolSettings settings) {
    if (_pageSize == Size.zero) return;
    setState(() {
      _currentStrokePoints = [
        ..._currentStrokePoints,
        NormalisedPoint(
          x: event.localPosition.dx / _pageSize.width,
          y: event.localPosition.dy / _pageSize.height,
          pressure: event.pressure.clamp(0.0, 1.0),
        ),
      ];
    });
  }

  Future<void> _handlePointerUp(
    PointerUpEvent event,
    ToolSettings settings,
  ) async {
    if (_currentStrokePoints.isEmpty) return;

    final stroke = InkStroke(
      id: const Uuid().v4(),
      tool: settings.activeTool,
      color: settings.color,
      strokeWidth: settings.strokeWidth,
      opacity: settings.opacity,
      points: List.from(_currentStrokePoints),
      createdAt: DateTime.now(),
    );

    setState(() => _currentStrokePoints = []);

    await ref
        .read(annotationServiceProvider(_pageKey).notifier)
        .addStroke(stroke);
  }
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({
    required this.layer,
    required this.currentPoints,
    required this.renderer,
    required this.pageSize,
    required this.currentTool,
  });

  final AnnotationLayer? layer;
  final List<NormalisedPoint> currentPoints;
  final InkRendererService renderer;
  final Size pageSize;
  final ToolSettings currentTool;

  @override
  void paint(Canvas canvas, Size size) {
    if (layer != null) {
      final renderData = renderer.buildRenderData(layer!, size);
      for (final data in renderData) {
        canvas.drawPath(data.path, data.paint);
      }
    }

    // Draw current in-progress stroke
    if (currentPoints.isNotEmpty) {
      final path = Path();
      final first = currentPoints.first;
      path.moveTo(first.x * size.width, first.y * size.height);
      for (final p in currentPoints.skip(1)) {
        path.lineTo(p.x * size.width, p.y * size.height);
      }

      final paint = Paint()
        ..color = currentTool.tool == AnnotationTool.eraser
            ? Colors.transparent
            : currentTool.color.withOpacity(currentTool.opacity)
        ..strokeWidth = currentTool.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (currentTool.tool == AnnotationTool.eraser) {
        paint.blendMode = BlendMode.clear;
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) =>
      oldDelegate.layer != layer || oldDelegate.currentPoints != currentPoints;
}

extension on ToolSettings {
  AnnotationTool get tool => activeTool;
}
