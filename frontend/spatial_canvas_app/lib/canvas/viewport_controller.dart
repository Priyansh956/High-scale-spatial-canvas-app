import 'package:flutter/material.dart';

class ViewportController extends ChangeNotifier {
  Offset panOffset = Offset.zero;
  double scale = 0.3; 

  static const double _minScale = 0.02;
  static const double _maxScale = 3.0;

  Offset _startPanOffset = Offset.zero;
  double _startScale = 1.0;
  Offset _startFocalPoint = Offset.zero;

  void onScaleStart(ScaleStartDetails details) {
    _startPanOffset = panOffset;
    _startScale = scale;
    _startFocalPoint = details.focalPoint;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final newScale = (_startScale * details.scale).clamp(_minScale, _maxScale);

    final focalDelta = details.focalPoint - _startFocalPoint;
    final scaleRatio = newScale / _startScale;

    panOffset = (_startPanOffset * scaleRatio) + focalDelta;
    scale = newScale;

    notifyListeners();
  }

  /// Converts a screen-space point to world-space coordinates,
  Offset screenToWorld(Offset screenPoint, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    return (screenPoint - center - panOffset) / scale;
  }

  /// Returns the current visible world-space bounding box
  Rect getViewportBounds(Size canvasSize) {
    final topLeft = screenToWorld(Offset.zero, canvasSize);
    final bottomRight = screenToWorld(Offset(canvasSize.width, canvasSize.height), canvasSize);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  Rect getBufferedViewportBounds(Size canvasSize, {double bufferFactor = 0.3}) {
    final bounds = getViewportBounds(canvasSize);
    final dx = bounds.width * bufferFactor;
    final dy = bounds.height * bufferFactor;
    return Rect.fromLTRB(
      bounds.left - dx,
      bounds.top - dy,
      bounds.right + dx,
      bounds.bottom + dy,
    );
  }
}
