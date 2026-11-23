import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic DayFlow surface can render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('dayflow.')),
      ),
    );

    expect(find.text('dayflow.'), findsOneWidget);
  });
}
