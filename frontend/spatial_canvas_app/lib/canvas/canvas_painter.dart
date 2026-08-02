import 'package:flutter/material.dart';
import '../models/spatial_object.dart';
import '../models/cluster_point.dart';
import 'quad_tree.dart';

class CanvasPainter extends CustomPainter {
  final List<SpatialObject> objects;
  final Offset panOffset;
  final double scale;
  final Set<String> selectedIds;
  final QuadTree<SpatialObject>? quadTree;

  // Live world-space positions for objects currently mid-drag, keyed by id.
  // Passed explicitly (rather than relying on the mutated object inside
  // `objects`) so shouldRepaint can actually detect the change every frame.
  final Map<String, Offset> draggingPositions;

  final List<Offset> dragTrail;

  final List<ClusterPoint> clusters;
  final bool isClusterMode;

  CanvasPainter({
    required this.objects,
    required this.panOffset,
    required this.scale,
    required this.quadTree,
    this.selectedIds = const {},
    this.draggingPositions = const {},
    this.dragTrail = const [],
    this.clusters = const [],
    this.isClusterMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF121212);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    canvas.save();
    canvas.translate(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);
    canvas.scale(scale);

    if (isClusterMode) {
      _paintClusters(canvas);
      canvas.restore();
      return;
    }

    final visibleWorldRect = Rect.fromCenter(
      center: Offset(-panOffset.dx / scale, -panOffset.dy / scale),
      width: size.width / scale,
      height: size.height / scale,
    );

    final visible = quadTree?.queryRange(visibleWorldRect).map((p) => p.data).toList() ?? objects;

    if (dragTrail.length > 1) {
      for (int i = 1; i < dragTrail.length; i++) {
        final trailPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(dragTrail[i - 1], dragTrail[i], trailPaint);
      }
    }

    for (final obj in visible) {
      final paint = Paint()..color = _parseColor(obj.color);
      final liveDragPos = draggingPositions[obj.id];
      final center = liveDragPos ?? Offset(obj.x, obj.y);

      switch (obj.shape) {
        case 'square':
          canvas.drawRect(
            Rect.fromCenter(center: center, width: obj.size * 2, height: obj.size * 2),
            paint,
          );
          break;
        case 'triangle':
          final path = Path()
            ..moveTo(center.dx, center.dy - obj.size)
            ..lineTo(center.dx - obj.size, center.dy + obj.size)
            ..lineTo(center.dx + obj.size, center.dy + obj.size)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case 'circle':
        default:
          canvas.drawCircle(center, obj.size, paint);
      }

      if (selectedIds.contains(obj.id)) {
        final highlightPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale;
        canvas.drawCircle(center, obj.size + 4, highlightPaint);
      }
    }

    canvas.restore();
  }

  void _paintClusters(Canvas canvas) {
    for (final c in clusters) {
      final radius = (8 + (c.count.clamp(1, 500)) * 0.15).clamp(8, 60).toDouble();
      final center = Offset(c.x, c.y);

      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.deepPurpleAccent.withValues(alpha: 0.6),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${c.count}',
          style: TextStyle(color: Colors.white, fontSize: 12 / scale),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedIds != selectedIds ||
        oldDelegate.quadTree != quadTree ||
        oldDelegate.draggingPositions != draggingPositions ||
        oldDelegate.dragTrail != dragTrail ||
        oldDelegate.clusters != clusters ||
        oldDelegate.isClusterMode != isClusterMode;
  }
}