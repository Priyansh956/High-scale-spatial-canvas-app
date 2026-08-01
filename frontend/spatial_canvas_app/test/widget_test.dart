import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spatial_canvas_app/main.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('App builds and renders the canvas without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const VisualliApp());
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}