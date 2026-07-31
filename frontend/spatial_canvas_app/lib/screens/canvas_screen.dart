import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/spatial_object.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  String _status = 'Checking backend connection...';
  List<SpatialObject> _objects = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkBackendThenFetch();
  }

  Future<void> _checkBackendThenFetch() async {
    final isHealthy = await ApiService.checkHealth();
    if (!isHealthy) {
      setState(() {
        _status = 'Could not reach backend';
      });
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
      appBar: AppBar(title: const Text('Visualli Canvas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_status, style: const TextStyle(fontSize: 16)),
          ),
          if (_loading) const CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _objects.length,
              itemBuilder: (context, index) {
                final obj = _objects[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(int.parse(obj.color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text('(${obj.x.toStringAsFixed(1)}, ${obj.y.toStringAsFixed(1)})'),
                  subtitle: Text('${obj.shape} · size ${obj.size}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}