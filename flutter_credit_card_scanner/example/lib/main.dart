import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_credit_card_scanner/flutter_credit_card_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  CreditCardScanResult? _lastResult;
  final _flutterCreditCardScannerPlugin = FlutterCreditCardScanner();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _flutterCreditCardScannerPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 24),
              Builder(
                builder: (innerContext) => ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(innerContext);
                    try {
                      final result = await _flutterCreditCardScannerPlugin.scanCard(scanExpiry: true, debug: true, showDetectedQuad: false, consensusRequired: 5, stabilityRequired: 3);
                      if (!mounted) return;
                      setState(() { _lastResult = result; });
                    } on PlatformException catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Scan error: ${e.message}')),
                      );
                    }
                  },
                  child: const Text('Scan Credit Card'),
                ),
              ),
              const SizedBox(height: 16),
              if (_lastResult != null) ...[
                const Text('Last scan:'),
                const SizedBox(height: 8),
                Text('Number: ${_lastResult!.cardNumber}'),
                Text('Brand: ${_lastResult!.cardBrand ?? '-'}'),
                Text('Expiry: ${_lastResult!.expiryMonth ?? '-'} / ${_lastResult!.expiryYear ?? '-'}'),
                Text('Name: ${_lastResult!.cardholderName ?? '-'}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}




