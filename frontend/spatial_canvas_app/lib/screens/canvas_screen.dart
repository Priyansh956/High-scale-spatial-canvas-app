import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spatial_canvas_app/widgets/fps_counter.dart';
import 'package:spatial_canvas_app/widgets/canvas_skeleton.dart';
import 'package:spatial_canvas_app/widgets/canvas_error_state.dart';
import '../services/api_service.dart';
import '../models/spatial_object.dart';
import '../models/cluster_point.dart';
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

  SpatialObject? _draggingObject;
  Offset? _dragStartWorldPos;
  double? _dragObjectStartX;
  double? _dragObjectStartY;
  List<Offset> _dragTrail = [];
  static const int _maxDragTrailPoints = 40;

  Offset? _gestureStartFocalPoint;
  bool _movedSignificantly = false;
  static const double _tapMovementThreshold = 8.0; // pixels

  bool _initialFetchDone = false;

  // Tier 1 additions: first-load skeleton vs. transient corner-spinner refetches,
  // real error state, and low-zoom clustering.
  bool _firstLoadComplete = false;
  bool _hasError = false;

  List<ClusterPoint> _clusters = [];
  bool _isClusterMode = false;
  static const double _clusterModeThreshold = 0.05; // switch to clusters below this zoom

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
  }

  Future<void> _checkBackendThenFetch(Size canvasSize) async {
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      setState(() {
        _status = 'Could not reach backend';
        _hasError = true;
      });
      return;
    }
    setState(() {
      _status = 'Connected';
      _hasError = false;
    });
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
    final scale = _viewportController.scale;
    final useClusters = scale < _clusterModeThreshold;

    final int thisGeneration = ++_fetchGeneration;
    setState(() => _loading = true);

    try {
      if (useClusters) {
        final gridSize = 500.0 / scale.clamp(0.001, 1.0);
        final clusters = await ApiService.fetchClusters(
          minX: bounds.left,
          minY: bounds.top,
          maxX: bounds.right,
          maxY: bounds.bottom,
          gridSize: gridSize,
        );

        if (thisGeneration != _fetchGeneration) return;

        setState(() {
          _clusters = clusters;
          _objects = [];
          _isClusterMode = true;
          _status = 'Showing ${clusters.length} clusters (zoomed out)';
          _loading = false;
          _firstLoadComplete = true;
          _hasError = false;
          _quadTree = null; // no per-object hit-testing in cluster mode
        });
        return;
      }

      final objects = await ApiService.fetchObjectsInViewport(
        minX: bounds.left,
        minY: bounds.top,
        maxX: bounds.right,
        maxY: bounds.bottom,
      );

      if (thisGeneration != _fetchGeneration) return;

      setState(() {
        _objects = objects;
        _clusters = [];
        _isClusterMode = false;
        _status = 'Loaded ${objects.length} objects';
        _loading = false;
        _firstLoadComplete = true;
        _hasError = false;
        _rebuildQuadTree();
      });
    } catch (e) {
      if (thisGeneration != _fetchGeneration) return;
      setState(() {
        _status = 'Fetch failed: $e';
        _loading = false;
        _hasError = true;
      });
    }
  }

  void _onScaleStart(ScaleStartDetails details, Size canvasSize) {
    _gestureStartFocalPoint = details.localFocalPoint;
    _movedSignificantly = false;

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

      if (nearest != null && nearest.data.id == _selectedId) {
        _draggingObject = nearest.data;
        _dragStartWorldPos = worldPoint;
        _dragObjectStartX = nearest.data.x;
        _dragObjectStartY = nearest.data.y;
        _dragTrail = [worldPoint];
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

        _dragTrail = [..._dragTrail, worldPoint];
        if (_dragTrail.length > _maxDragTrailPoints) {
          _dragTrail = _dragTrail.sublist(_dragTrail.length - _maxDragTrailPoints);
        }
      });
      return;
    }

    _viewportController.onScaleUpdate(details);
    _onViewportChanged(canvasSize);
  }

  Future<void> _onScaleEnd(ScaleEndDetails details, Size canvasSize) async {
    if (_draggingObject != null) {
      final obj = _draggingObject!;
      final rollbackX = _dragObjectStartX!;
      final rollbackY = _dragObjectStartY!;
      _draggingObject = null;

      try {
        await ApiService.updateObjectPosition(obj.id, obj.x, obj.y);
        setState(() {
          _dragTrail = [];
          _rebuildQuadTree();
        });
      } catch (e) {
        setState(() {
          obj.x = rollbackX;
          obj.y = rollbackY;
          _dragTrail = [];
          _status = 'Failed to save move: $e';
          _rebuildQuadTree();
        });
      }
      return;
    }

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
      setState(() {
        _selectedId = nearest?.data.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_status, style: const TextStyle(fontSize: 14)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;

          if (!_initialFetchDone && size.width > 0 && size.height > 0 && size.isFinite) {
            _initialFetchDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkBackendThenFetch(size);
            });
          }

          // First load never happened yet — show the skeleton, not a blank canvas.
          if (!_firstLoadComplete && !_hasError) {
            return const CanvasSkeleton();
          }

          // First load itself failed — show a real error state with retry,
          // not just AppBar text over an empty screen.
          if (!_firstLoadComplete && _hasError) {
            return CanvasErrorState(
              message: _status,
              onRetry: () => _checkBackendThenFetch(size),
            );
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
                          clusters: _clusters,
                          isClusterMode: _isClusterMode,
                          panOffset: _viewportController.panOffset,
                          scale: _viewportController.scale,
                          selectedId: _selectedId,
                          quadTree: _quadTree,
                          draggingId: _draggingObject?.id,
                          draggingPosition: _draggingObject != null
                              ? Offset(_draggingObject!.x, _draggingObject!.y)
                              : null,
                          dragTrail: _dragTrail,
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

              const Positioned(top: 8, left: 8, child: FpsCounter()),
            ],
          );
        },
      ),
    );
  }
}