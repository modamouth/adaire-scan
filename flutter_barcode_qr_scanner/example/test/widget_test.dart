import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_barcode_qr_scanner_example/main.dart';

void main() {
  testWidgets('shows bounded physical-test controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data?.startsWith('Running on:') ?? false),
      ),
      findsOneWidget,
    );
    expect(find.text('Allowed barcode formats'), findsOneWidget);
    expect(find.text('QR, EAN-13, and Code 128'), findsOneWidget);
    expect(find.text('Start scan'), findsOneWidget);
    expect(find.text('Run concurrent invocation test'), findsOneWidget);
    expect(find.text('Session evidence'), findsOneWidget);
    expect(find.text('No result displayed'), findsOneWidget);
  });

  testWidgets('offers each approved single-format profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('QR, EAN-13, and Code 128'));
    await tester.pumpAndSettle();

    expect(find.text('QR only'), findsOneWidget);
    expect(find.text('EAN-13 only'), findsOneWidget);
    expect(find.text('Code 128 only'), findsOneWidget);
  });
}
