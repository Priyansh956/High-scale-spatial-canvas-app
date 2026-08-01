import 'package:flutter/material.dart';
import '../models/spatial_object.dart';
import 'quad_tree.dart';

class CanvasPainter extends CustomPainter {
  final List<SpatialObject> objects;
  final Offset panOffset;
  final double scale;
  final String? selectedId;
  final QuadTree<SpatialObject>? quadTree;

  CanvasPainter({
    required this.objects,
    required this.panOffset,
    required this.scale,
    required this.quadTree,
    this.selectedId,
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

    for (final obj in visible) {
      final paint = Paint()..color = _parseColor(obj.color);
      final center = Offset(obj.x, obj.y);

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
        oldDelegate.selectedId != selectedId;
  }
}