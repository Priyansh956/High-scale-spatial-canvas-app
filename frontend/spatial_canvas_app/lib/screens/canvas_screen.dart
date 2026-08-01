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

  @override
  void initState() {
    super.initState();
    _checkBackendThenFetch();
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  Future<void> _checkBackendThenFetch() async {
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      setState(() => _status = 'Could not reach backend');
      return;
    }

    setState(() {
      _status = 'Connected — fetching objects...';
      _loading = true;
    });

    try {
      final objects = await ApiService.fetchObjectsInViewport(
        minX: -1000,
        minY: -1000,
        maxX: 1000,
        maxY: 1000,
      );
      setState(() {
        _objects = objects;
        _status = 'Loaded ${objects.length} objects';
        _loading = false;
      });
    } catch (e) {
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onScaleStart: _viewportController.onScaleStart,
              onScaleUpdate: _viewportController.onScaleUpdate,
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
    );
  }
}