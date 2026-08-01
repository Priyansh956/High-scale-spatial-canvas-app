import 'dart:async';
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

  // Drag state — null when not currently dragging an object.
  SpatialObject? _draggingObject;
  Offset? _dragStartWorldPos;
  double? _dragObjectStartX;
  double? _dragObjectStartY;

  // Tap-vs-drag/pan disambiguation state.
  Offset? _gestureStartFocalPoint;
  bool _movedSignificantly = false;
  static const double _tapMovementThreshold = 8.0; // pixels

  bool _initialFetchDone = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _viewportController.dispose();
    super.dispose();
  }

  void _rebuildQuadTree() {
    final tree = QuadTree<SpatialObject>(
      const Rect.fromLTRB(-10000, -10000, 10000, 10000),
    );
    for (final obj in _objects) {
      tree.insert(QuadPoint(Offset(obj.x, obj.y), obj));
    }
    _quadTree = tree;
    debugPrint(
      'Quadtree rebuilt: ${_objects.length} objects in list, ${tree.count()} points in tree',
    );
  }

  Future<void> _checkBackendThenFetch(Size canvasSize) async {
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      setState(() => _status = 'Could not reach backend');
      return;
    }
    setState(() => _status = 'Connected');
    await _fetchForCurrentViewport(canvasSize);
  }

  void _onViewportChanged(Size canvasSize) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _fetchForCurrentViewport(canvasSize);
    });
  }

  Future<void> _fetchForCurrentViewport(Size canvasSize) async {
    final bounds = _viewportController.getBufferedViewportBounds(canvasSize);

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

  double _toleranceWorld() => 20.0 / _viewportController.scale;

  void _onScaleStart(ScaleStartDetails details, Size canvasSize) {
    _gestureStartFocalPoint = details.localFocalPoint;
    _movedSignificantly = false;

    debugPrint(
      'onScaleStart: selectedId=$_selectedId, hasQuadTree=${_quadTree != null}, canvasSize=$canvasSize',
    );

    if (_selectedId != null && _quadTree != null) {
      final worldPoint = _viewportController.screenToWorld(
        details.localFocalPoint,
        canvasSize,
      );
      final nearest = _quadTree!.hitTest(
        worldPoint,
        (obj) => obj.size,
        8.0 / _viewportController.scale,
      );
      debugPrint(
        'onScaleStart: worldPoint=$worldPoint, nearestId=${nearest?.data.id}, matchesSelected=${nearest?.data.id == _selectedId}',
      );

      if (nearest != null && nearest.data.id == _selectedId) {
        _draggingObject = nearest.data;
        _dragStartWorldPos = worldPoint;
        _dragObjectStartX = nearest.data.x;
        _dragObjectStartY = nearest.data.y;
        debugPrint('onScaleStart: DRAG STARTED for ${nearest.data.id}');
        return;
      }
    }

    _draggingObject = null;
    _viewportController.onScaleStart(details);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    final movedDist =
        (details.localFocalPoint - _gestureStartFocalPoint!).distance;
    if (movedDist > _tapMovementThreshold) _movedSignificantly = true;

    if (_draggingObject != null) {
      final worldPoint = _viewportController.screenToWorld(
        details.localFocalPoint,
        canvasSize,
      );
      final delta = worldPoint - _dragStartWorldPos!;

      setState(() {
        _draggingObject!.x = _dragObjectStartX! + delta.dx;
        _draggingObject!.y = _dragObjectStartY! + delta.dy;
      });
      return;
    }

    _viewportController.onScaleUpdate(details);
    _onViewportChanged(canvasSize);
  }

  Future<void> _onScaleEnd(ScaleEndDetails details, Size canvasSize) async {
    // Case 1: was dragging an object — persist the move.
    if (_draggingObject != null) {
      final obj = _draggingObject!;
      final rollbackX = _dragObjectStartX!;
      final rollbackY = _dragObjectStartY!;
      _draggingObject = null;

      try {
        await ApiService.updateObjectPosition(obj.id, obj.x, obj.y);
        setState(() => _rebuildQuadTree());
      } catch (e) {
        setState(() {
          obj.x = rollbackX;
          obj.y = rollbackY;
          _status = 'Failed to save move: $e';
          _rebuildQuadTree();
        });
      }
      return;
    }

    // Case 2: finger barely moved and we weren't dragging — treat as a tap-to-select.
    debugPrint(
      'onScaleEnd: movedSignificantly=$_movedSignificantly, hasFocalPoint=${_gestureStartFocalPoint != null}, hasQuadTree=${_quadTree != null}',
    );
    if (!_movedSignificantly &&
        _gestureStartFocalPoint != null &&
        _quadTree != null) {
      final worldPoint = _viewportController.screenToWorld(
        _gestureStartFocalPoint!,
        canvasSize,
      );

      final nearest = _quadTree!.hitTest(
        worldPoint,
        (obj) => obj.size,
        8.0 / _viewportController.scale,
      );

      debugPrint(
        'tap worldPoint=$worldPoint, tolerance=${_toleranceWorld()}, nearest=${nearest?.data.id}',
      );
      setState(() {
        _selectedId = nearest?.data.id; // tapping empty space deselects
      });
    }

    // Case 3: it was a real pan gesture — nothing further to do.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_status, style: const TextStyle(fontSize: 14)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest; // the ACTUAL body render size

          // Kick off the initial fetch exactly once, now that we know the
          // real canvas size (can't do this in initState — no layout yet).
          if (!_initialFetchDone) {
            _initialFetchDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkBackendThenFetch(size);
            });
          }

          return Stack(
            children: [
              GestureDetector(
                onScaleStart: (details) => _onScaleStart(details, size),
                onScaleUpdate: (details) => _onScaleUpdate(details, size),
                onScaleEnd: (details) => _onScaleEnd(details, size),
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
                        size: size,
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
          );
        },
      ),
    );
  }
}