import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benguet_harvest/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const BenguetHarvestApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
