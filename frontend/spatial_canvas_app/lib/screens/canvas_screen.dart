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

  final ViewportController _viewportController = ViewportController();
  QuadTree<SpatialObject>? _quadTree;

  Timer? _debounceTimer;
  int _fetchGeneration = 0;

  // --- Selection ---
  Set<String> _selectedIds = {};
  bool _multiSelectMode = false;

  List<SpatialObject> _draggingObjects = [];
  Map<String, Offset> _dragStartPositions = {};
  Offset? _dragStartWorldPos;

  List<Offset> _dragTrail = [];
  static const int _maxDragTrailPoints = 40;

  Offset? _gestureStartFocalPoint;
  bool _movedSignificantly = false;
  static const double _tapMovementThreshold = 8.0; // pixels

  bool _initialFetchDone = false;
  bool _firstLoadComplete = false;
  bool _hasError = false;

  List<ClusterPoint> _clusters = [];
  bool _isClusterMode = false;
  static const double _clusterModeThreshold = 0.05;

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
          _quadTree = null;
          _selectedIds = {}; // selection doesn't survive into cluster mode
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
        // Drop any selected ids that fell outside the newly fetched region.
        final fetchedIds = objects.map((o) => o.id).toSet();
        _selectedIds = _selectedIds.intersection(fetchedIds);
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

    if (_selectedIds.isNotEmpty && _quadTree != null) {
      final worldPoint = _viewportController.screenToWorld(
        details.localFocalPoint,
        canvasSize,
      );
      final hit = _quadTree!.hitTest(
        worldPoint,
        (obj) => obj.size,
        8.0 / _viewportController.scale,
      );

      // Gesture starts a bulk drag only if it lands on an object that's
      // actually part of the current selection — otherwise it's a pan.
      if (hit != null && _selectedIds.contains(hit.data.id)) {
        _draggingObjects = _objects.where((o) => _selectedIds.contains(o.id)).toList();
        _dragStartPositions = {
          for (final o in _draggingObjects) o.id: Offset(o.x, o.y),
        };
        _dragStartWorldPos = worldPoint;
        _dragTrail = [worldPoint];
        return;
      }
    }

    _draggingObjects = [];
    _viewportController.onScaleStart(details);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    final movedDist =
        (details.localFocalPoint - _gestureStartFocalPoint!).distance;
    if (movedDist > _tapMovementThreshold) _movedSignificantly = true;

    if (_draggingObjects.isNotEmpty) {
      final worldPoint = _viewportController.screenToWorld(
        details.localFocalPoint,
        canvasSize,
      );
      final delta = worldPoint - _dragStartWorldPos!;

      setState(() {
        for (final obj in _draggingObjects) {
          final start = _dragStartPositions[obj.id]!;
          obj.x = start.dx + delta.dx;
          obj.y = start.dy + delta.dy;
        }

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
    if (_draggingObjects.isNotEmpty) {
      final draggedObjects = _draggingObjects;
      final startPositions = _dragStartPositions;
      _draggingObjects = [];
      _dragStartPositions = {};

      final failedObjects = <SpatialObject>[];
      await Future.wait(draggedObjects.map((obj) async {
        try {
          await ApiService.updateObjectPosition(obj.id, obj.x, obj.y);
        } catch (_) {
          failedObjects.add(obj);
        }
      }));

      setState(() {
        for (final obj in failedObjects) {
          final start = startPositions[obj.id]!;
          obj.x = start.dx;
          obj.y = start.dy;
        }
        _dragTrail = [];
        if (failedObjects.isNotEmpty) {
          _status = failedObjects.length == draggedObjects.length
              ? 'Failed to save move'
              : 'Saved ${draggedObjects.length - failedObjects.length}/${draggedObjects.length} — ${failedObjects.length} rolled back';
        }
        _rebuildQuadTree();
      });
      return;
    }

    if (!_movedSignificantly &&
        _gestureStartFocalPoint != null &&
        _quadTree != null) {
      final worldPoint = _viewportController.screenToWorld(
        _gestureStartFocalPoint!,
        canvasSize,
      );
      final hit = _quadTree!.hitTest(
        worldPoint,
        (obj) => obj.size,
        8.0 / _viewportController.scale,
      );

      setState(() {
        if (_multiSelectMode) {
          if (hit == null) {
            _selectedIds = {};
          } else {
            final id = hit.data.id;
            _selectedIds = {..._selectedIds};
            if (_selectedIds.contains(id)) {
              _selectedIds.remove(id);
            } else {
              _selectedIds.add(id);
            }
          }
        } else {
          _selectedIds = hit != null ? {hit.data.id} : {};
        }
      });
    }
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode && _selectedIds.length > 1) {
        _selectedIds = {_selectedIds.first};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_status, style: const TextStyle(fontSize: 14)),
        actions: [
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear selection',
              onPressed: () => setState(() => _selectedIds = {}),
            ),
          IconButton(
            icon: Icon(_multiSelectMode ? Icons.check_box : Icons.check_box_outline_blank),
            tooltip: _multiSelectMode ? 'Exit multi-select' : 'Multi-select mode',
            onPressed: _toggleMultiSelectMode,
          ),
        ],
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

          if (!_firstLoadComplete && !_hasError) {
            return const CanvasSkeleton();
          }

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
                          selectedIds: _selectedIds,
                          quadTree: _quadTree,
                          draggingPositions: {
                            for (final o in _draggingObjects) o.id: Offset(o.x, o.y),
                          },
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
              if (_multiSelectMode)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Multi-select: tap to add/remove · drag any selected shape to move all',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}