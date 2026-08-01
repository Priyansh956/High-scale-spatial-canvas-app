import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/spatial_object.dart';
import '../canvas/canvas_painter.dart';
import '../canvas/viewport_controller.dart';

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

  Timer? _debounceTimer;
  int _fetchGeneration = 0; // incremented on every new fetch; guards against stale responses

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

  Future<void> _checkBackendThenFetch() async {
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      setState(() => _status = 'Could not reach backend');
      return;
    }
    setState(() => _status = 'Connected');
    await _fetchForCurrentViewport();
  }

  /// Called on every gesture frame — but only actually fetches after the
  /// user stops interacting for a short pause (debounce), not on every frame.
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

      // If a newer fetch has started since this one began, discard this
      // (now-stale) result rather than overwriting fresher data.
      if (thisGeneration != _fetchGeneration) return;

      setState(() {
        _objects = objects;
        _status = 'Loaded ${objects.length} objects';
        _loading = false;
      });
    } catch (e) {
      if (thisGeneration != _fetchGeneration) return;
      setState(() {
        _status = 'Fetch failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _viewportController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: CanvasPainter(
                      objects: _objects,
                      panOffset: _viewportController.panOffset,
                      scale: _viewportController.scale,
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