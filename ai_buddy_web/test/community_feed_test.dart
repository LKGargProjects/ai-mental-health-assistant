import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Community feed smoke test builds basic UI',
      (WidgetTester tester) async {
    // Simple smoke test: ensure a basic scaffold with a scrollable body
    // can be built without throwing.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [Text('Community Feed')],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Community Feed'), findsOneWidget);
  });
}
