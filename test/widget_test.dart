// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:profilertestapp/main.dart';

void main() {
  testWidgets('Binary Runner basic UI renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OneScreenApp());

    // App bar title
    expect(find.text('Binary Runner'), findsOneWidget);

    // Input fields
    expect(find.widgetWithText(TextField, 'path'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'binary_name'), findsOneWidget);

    // Run button text and icon present
    expect(find.text('Run'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
