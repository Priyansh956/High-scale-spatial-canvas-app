import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_canvas_app/main.dart';

void main() {
  testWidgets('App builds and renders the canvas without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VisualliApp());

    // Let the async health-check/fetch attempt resolve (it'll fail here since
    // there's no real backend in the test sandbox — that's expected).
    await tester.pumpAndSettle();

    // Regardless of backend connectivity, the canvas widget itself should render.
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
