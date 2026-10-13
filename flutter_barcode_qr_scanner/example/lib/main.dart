import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';

void main() {
  runApp(const MyApp());
}

enum _ScanProfile {
  all('QR, EAN-13, and Code 128', <BarcodeFormat>[
    BarcodeFormat.qr,
    BarcodeFormat.ean13,
    BarcodeFormat.code128,
  ]),
  qrOnly('QR only', <BarcodeFormat>[BarcodeFormat.qr]),
  ean13Only('EAN-13 only', <BarcodeFormat>[BarcodeFormat.ean13]),
  code128Only('Code 128 only', <BarcodeFormat>[BarcodeFormat.code128]);

  const _ScanProfile(this.label, this.formats);

  final String label;
  final List<BarcodeFormat> formats;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _scanner = FlutterBarcodeQrScanner();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  _ScanProfile _profile = _ScanProfile.all;
  ScanResult? _lastResult;
  ScanOutcomeType? _lastOutcome;
  String? _concurrentResult;
  int _completedAttempts = 0;
  int _successfulAttempts = 0;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _scanner.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;
    setState(() => _platformVersion = platformVersion);
  }

  Future<void> _startSingleScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _concurrentResult = null;
    });

    final outcome = await _scanner.scan(formats: _profile.formats);
    if (!mounted) return;
    _recordOutcome(outcome);
    setState(() => _isScanning = false);
  }

  Future<void> _startConcurrentTest() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _concurrentResult = 'Waiting for both scan outcomes';
    });

    final first = _scanner.scan(formats: _profile.formats);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final second = _scanner.scan(formats: _profile.formats);
    final outcomes = await Future.wait(<Future<ScanOutcome>>[first, second]);
    if (!mounted) return;

    for (final outcome in outcomes) {
      _recordOutcome(outcome, showMessage: false);
    }
    final outcomeNames = outcomes
        .map((outcome) => outcome.type.name)
        .join(', ');
    final passed =
        outcomes
            .where((outcome) => outcome.type == ScanOutcomeType.busy)
            .length ==
        1;
    setState(() {
      _isScanning = false;
      _concurrentResult = passed
          ? 'PASS: exactly one busy outcome ($outcomeNames)'
          : 'REVIEW: expected exactly one busy outcome ($outcomeNames)';
    });
  }

  void _recordOutcome(ScanOutcome outcome, {bool showMessage = true}) {
    setState(() {
      _completedAttempts += 1;
      _lastOutcome = outcome.type;
      if (outcome.isSuccess) {
        _successfulAttempts += 1;
        _lastResult = outcome.result;
      }
    });

    if (showMessage && !outcome.isSuccess) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(_messageFor(outcome.type))),
      );
    }
  }

  String _messageFor(ScanOutcomeType type) => switch (type) {
    ScanOutcomeType.cancelled => 'Scan cancelled',
    ScanOutcomeType.permissionDenied =>
      'Camera permission denied. Enable it in Android Settings, then retry.',
    ScanOutcomeType.unavailable => 'Scanner unavailable on this device',
    ScanOutcomeType.busy => 'A scan is already in progress',
    ScanOutcomeType.failure => 'Scan failed',
    ScanOutcomeType.success => 'Scan completed',
  };

  void _clearDisplayedPayload() {
    setState(() => _lastResult = null);
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Displayed result cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('Adaire Barcode/QR Test')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 16),
              DropdownButtonFormField<_ScanProfile>(
                initialValue: _profile,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Allowed barcode formats',
                  helperText:
                      'Use a single-format profile for filtering tests.',
                ),
                items: _ScanProfile.values
                    .map(
                      (profile) => DropdownMenuItem<_ScanProfile>(
                        value: profile,
                        child: Text(profile.label),
                      ),
                    )
                    .toList(),
                onChanged: _isScanning
                    ? null
                    : (profile) {
                        if (profile != null) setState(() => _profile = profile);
                      },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isScanning ? null : _startSingleScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_isScanning ? 'Scan in progress' : 'Start scan'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isScanning ? null : _startConcurrentTest,
                child: const Text('Run concurrent invocation test'),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session evidence',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Completed attempts: $_completedAttempts'),
                        Text('Successful attempts: $_successfulAttempts'),
                        Text('Last outcome: ${_lastOutcome?.name ?? 'none'}'),
                        if (_concurrentResult != null) Text(_concurrentResult!),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explicit scan result',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _lastResult == null
                            ? 'No result displayed'
                            : 'Type: ${_lastResult!.type.name}\n'
                                  'Value: ${_lastResult!.value}',
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _lastResult == null
                            ? null
                            : _clearDisplayedPayload,
                        child: const Text('Clear displayed result'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Physical test guidance',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Filtering: select QR only, present an EAN-13 or Code '
                        '128 fixture, confirm it is not accepted, then close.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Permission: deny camera access, retry once, then grant '
                        'access in Android Settings and confirm recovery.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Lifecycle: start a scan, send the app to the background, '
                        'return to it, then complete or close the scan.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use synthetic fixtures only. Do not include decoded '
                        'values in screenshots, logs, or evidence records.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
