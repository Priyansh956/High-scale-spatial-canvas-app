// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_canvas_app/main.dart';

void main() {
  testWidgets('App renders CanvasScreen with title', (WidgetTester tester) async {
    await tester.pumpWidget(const VisualliApp());

    expect(find.text('Visualli Canvas'), findsOneWidget);
  });
}