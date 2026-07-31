import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  String _status = 'Checking backend connection...';

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    final isHealthy = await ApiService.checkHealth();
    setState(() {
      _status = isHealthy
          ? 'Connected to backend'
          : 'Could not reach backend — check it\'s running on localhost:4000';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visualli Canvas')),
      body: Center(
        child: Text(_status, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}