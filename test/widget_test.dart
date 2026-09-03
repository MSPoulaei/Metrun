import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masiryab_metro/main.dart';

void main() {
  testWidgets('App smoke test - verifies initial widgets and title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify AppBar title
    expect(find.text('Metro Tehran Navigator'), findsOneWidget);

    // Verify map button exists in AppBar
    expect(find.byIcon(Icons.map), findsOneWidget);
  });
}
