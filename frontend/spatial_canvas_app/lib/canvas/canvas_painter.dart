import 'package:flutter/material.dart';
import '../models/spatial_object.dart';
import 'quad_tree.dart';

class CanvasPainter extends CustomPainter {
  final List<SpatialObject> objects;
  final Offset panOffset;
  final double scale;
  final String? selectedId;
  final QuadTree<SpatialObject>? quadTree;

  // Position of the object currently being dragged (world coords), and its
  // id. Passed explicitly (rather than relying on the mutated object inside
  // `objects`) so shouldRepaint can actually detect the change every frame.
  final String? draggingId;
  final Offset? draggingPosition;

  // Trail of recent world-space points the finger has passed through while
  // dragging, used to draw a real-time path trace.
  final List<Offset> dragTrail;

  CanvasPainter({
    required this.objects,
    required this.panOffset,
    required this.scale,
    required this.quadTree,
    this.selectedId,
    this.draggingId,
    this.draggingPosition,
    this.dragTrail = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF121212);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    canvas.save();
    canvas.translate(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);
    canvas.scale(scale);

    // Cull to only what's actually visible, using the quadtree instead of
    // looping the full fetched list — this is what lets rendering cost stay
    // flat even as more of the dataset gets held in memory over a session.
    final visibleWorldRect = Rect.fromCenter(
      center: Offset(-panOffset.dx / scale, -panOffset.dy / scale),
      width: size.width / scale,
      height: size.height / scale,
    );

    final visible = quadTree?.queryRange(visibleWorldRect).map((p) => p.data).toList() ?? objects;

    // Draw the real-time drag trail underneath everything else, fading out
    // toward the older points.
    if (dragTrail.length > 1) {
      for (int i = 1; i < dragTrail.length; i++) {
        final t = i / dragTrail.length; // 0 (oldest) -> 1 (newest)
        final trailPaint = Paint()
          ..color = Colors.white.withOpacity(0.05 + 0.35 * t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(dragTrail[i - 1], dragTrail[i], trailPaint);
      }
    }

    for (final obj in visible) {
      final paint = Paint()..color = _parseColor(obj.color);
      // Use the live drag position for the object currently being dragged,
      // since `obj` itself may be a stale reference from a cached query.
      final center = (obj.id == draggingId && draggingPosition != null)
          ? draggingPosition!
          : Offset(obj.x, obj.y);

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

      if (obj.id == selectedId) {
        final highlightPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale;
        canvas.drawCircle(center, obj.size + 4, highlightPaint);
      }
    }

    canvas.restore();
  }

  Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.quadTree != quadTree ||
        oldDelegate.draggingId != draggingId ||
        oldDelegate.draggingPosition != draggingPosition ||
        oldDelegate.dragTrail != dragTrail;
  }
}