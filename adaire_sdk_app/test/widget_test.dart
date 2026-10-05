// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:adaire_sdk_app/app/app.dart';

void main() {
  testWidgets('App renders showcase grid', (WidgetTester tester) async {
    await tester.pumpWidget(const AdaireSdkApp());

    expect(find.text('Adaire Scan: SDK Showcase'), findsOneWidget);
    expect(find.text('Barcode / QR Scanner'), findsOneWidget);
    expect(find.text('Credit Card Scanner'), findsOneWidget);
  });
}
