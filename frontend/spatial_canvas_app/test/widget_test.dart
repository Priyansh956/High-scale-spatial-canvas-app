import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spatial_canvas_app/main.dart';

void main() {
  setUpAll(() {
    dotenv.env['API_BASE_URL'] = 'http://localhost:4000';
  });

  testWidgets('App builds and renders the canvas without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const VisualliApp());
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}