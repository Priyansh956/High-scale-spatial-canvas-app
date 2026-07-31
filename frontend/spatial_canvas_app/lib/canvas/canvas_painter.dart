import 'package:flutter/material.dart';
import '../models/spatial_object.dart';

class CanvasPainter extends CustomPainter {
  final List<SpatialObject> objects;
  final Offset panOffset;
  final double scale;

  CanvasPainter({
    required this.objects,
    required this.panOffset,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed background so empty canvas space isn't just transparent/white
    final backgroundPaint = Paint()..color = const Color(0xFF121212);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    canvas.save();
    // Center the origin on screen, then apply pan + zoom
    canvas.translate(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);
    canvas.scale(scale);

    for (final obj in objects) {
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
        oldDelegate.scale != scale;
  }
}