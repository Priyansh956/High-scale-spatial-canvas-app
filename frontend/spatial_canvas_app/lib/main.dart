import 'package:flutter/material.dart';
import 'package:spatial_canvas_app/screens/canvas_screen.dart';

void main() {
  runApp(const VisualliApp());
}

class VisualliApp extends StatelessWidget {
  const VisualliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visualli',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const CanvasScreen()
    );
  }
}