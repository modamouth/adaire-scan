import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner.dart';

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
  final _flutterPassportScannerPlugin = FlutterPassportScanner();
  bool _isScanning = false;
  PassportScanResult? _scanResult;

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
          await _flutterPassportScannerPlugin.getPlatformVersion() ?? 'Unknown platform version';
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

  Future<void> _scan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanResult = null;
    });
    try {
      final result = await _flutterPassportScannerPlugin.scanPassport(
        options: const PassportScanOptions(pageLimit: 1, allowGalleryImport: false),
      );
      if (!mounted) return;
      setState(() {
        _scanResult = result;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Scan failed')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Passport Scanner Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isScanning ? null : _scan,
                child: Text(_isScanning ? 'Scanning…' : 'Scan Passport'),
              ),
              const SizedBox(height: 16),
              if (_scanResult == null) const Text('No scan yet.'),
              if (_scanResult != null) ...[
                Text('Images: ${_scanResult!.imagePaths.length}'),
                const SizedBox(height: 8),
                if (_scanResult!.mrz == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MRZ: not found'),
                      if ((_scanResult!.rawOcrText ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Show raw OCR text'),
                          children: [
                            SelectableText(_scanResult!.rawOcrText!),
                          ],
                        ),
                      ],
                    ],
                  )
                else ...[
                  Text('MRZ valid: ${_scanResult!.mrz!.isValid}'),
                  Text('Name: ${_scanResult!.mrz!.givenNames} ${_scanResult!.mrz!.surnames}'),
                  Text('Passport #: ${_scanResult!.mrz!.passportNumber}'),
                  Text('Nationality: ${_scanResult!.mrz!.nationality}'),
                  Text('DOB: ${_scanResult!.mrz!.dateOfBirth?.toIso8601String() ?? ""}'),
                  Text('Expiry: ${_scanResult!.mrz!.dateOfExpiry?.toIso8601String() ?? ""}'),
                  if (_scanResult!.mrz!.errors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Validation issues:'),
                    for (final e in _scanResult!.mrz!.errors) Text('- $e'),
                  ],
                ],
                if (_scanResult!.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Expanded(
                    child: Image.file(
                      File(_scanResult!.imagePaths.first),
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
