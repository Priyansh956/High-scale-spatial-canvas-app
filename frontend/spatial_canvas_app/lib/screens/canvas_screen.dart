import 'dart:async';
// import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/spatial_object.dart';
import '../canvas/canvas_painter.dart';
import '../canvas/viewport_controller.dart';
import '../canvas/quad_tree.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  String _status = 'Checking backend connection...';
  List<SpatialObject> _objects = [];
  bool _loading = false;
  String? _selectedId;

  final ViewportController _viewportController = ViewportController();
  QuadTree<SpatialObject>? _quadTree;

  Timer? _debounceTimer;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _checkBackendThenFetch();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _viewportController.dispose();
    super.dispose();
  }

  void _rebuildQuadTree() {
    // World-space bounds match the full seeded plane (-10000..10000).
    final tree = QuadTree<SpatialObject>(
      const Rect.fromLTRB(-10000, -10000, 10000, 10000),
    );
    for (final obj in _objects) {
      tree.insert(QuadPoint(Offset(obj.x, obj.y), obj));
    }
    _quadTree = tree;
  }

  Future<void> _checkBackendThenFetch() async {
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      setState(() => _status = 'Could not reach backend');
      return;
    }
    setState(() => _status = 'Connected');
    await _fetchForCurrentViewport();
  }

  void _onViewportChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _fetchForCurrentViewport();
    });
  }

  Future<void> _fetchForCurrentViewport() async {
    final size = MediaQuery.of(context).size;
    final bounds = _viewportController.getBufferedViewportBounds(size);

    final int thisGeneration = ++_fetchGeneration;
    setState(() => _loading = true);

    try {
      final objects = await ApiService.fetchObjectsInViewport(
        minX: bounds.left,
        minY: bounds.top,
        maxX: bounds.right,
        maxY: bounds.bottom,
      );

      if (thisGeneration != _fetchGeneration) return;

      setState(() {
        _objects = objects;
        _status = 'Loaded ${objects.length} objects';
        _loading = false;
        _rebuildQuadTree();
      });
    } catch (e) {
      if (thisGeneration != _fetchGeneration) return;
      setState(() {
        _status = 'Fetch failed: $e';
        _loading = false;
      });
    }
  }

  void _onTapUp(TapUpDetails details, Size canvasSize) {
    if (_quadTree == null) return;

    final worldPoint = _viewportController.screenToWorld(details.localPosition, canvasSize);

    // Tap tolerance in screen pixels, converted to world units by dividing
    // by scale — so the tap target feels consistent regardless of zoom level.
    const tapTolerancePx = 20.0;
    final toleranceWorld = tapTolerancePx / _viewportController.scale;

    final nearest = _quadTree!.findNearest(worldPoint, toleranceWorld);

    setState(() {
      _selectedId = nearest?.data.id; // tapping empty space deselects
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: Text(_status, style: const TextStyle(fontSize: 14))),
      body: Stack(
        children: [
          GestureDetector(
            onScaleStart: _viewportController.onScaleStart,
            onScaleUpdate: (details) {
              _viewportController.onScaleUpdate(details);
              _onViewportChanged();
            },
            onTapUp: (details) => _onTapUp(details, size),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _viewportController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: CanvasPainter(
                      objects: _objects,
                      panOffset: _viewportController.panOffset,
                      scale: _viewportController.scale,
                      selectedId: _selectedId,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
          if (_loading)
            const Positioned(
              top: 8,
              right: 8,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}