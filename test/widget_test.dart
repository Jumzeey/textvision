// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:textvision/main.dart';

void main() {
  testWidgets('TextVision app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TextVisionApp());

    // Verify that the app title is displayed
    expect(find.text('TextVision'), findsOneWidget);
    expect(find.text('Exam Assistant for Blind Students'), findsOneWidget);

    // Verify that the scan buttons are present
    expect(find.text('Scan Printed Text'), findsOneWidget);
    expect(find.text('Scan Handwriting'), findsOneWidget);
  });
}
