import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/canvas_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before any async work pre-runApp
  await dotenv.load(fileName: '.env');
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
      home: const CanvasScreen(),
    );
  }
}