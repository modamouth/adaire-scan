import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_id_scanner/flutter_id_scanner.dart';

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
  final _flutterIdScannerPlugin = FlutterIdScanner();

  bool _isScanning = false;
  IdCaptureSide? _nextPrompt;
  IdScanResult? _result;

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
          await _flutterIdScannerPlugin.getPlatformVersion() ??
          'Unknown platform version';
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
      _nextPrompt = null;
      _result = null;
    });
    try {
      final res = await _flutterIdScannerPlugin.scanIdCard(
        options: const IdScanOptions(
          allowGalleryImport: false,
          performOcr: true,
        ),
        onProgress: (side) {
          if (!mounted) return;
          setState(() {
            _nextPrompt = side;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _result = res;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Scan failed')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _nextPrompt = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('ID Scanner Example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 12),
              if (_nextPrompt != null) ...[
                Text(
                  _nextPrompt == IdCaptureSide.front
                      ? 'Capture the FRONT of the ID'
                      : 'Capture the BACK of the ID',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _isScanning ? null : _scan,
                child: Text(
                  _isScanning ? 'Scanning…' : 'Scan ID (Front + Back)',
                ),
              ),
              const SizedBox(height: 16),
              if (_result == null) const Text('No scan yet.'),
              if (_result != null) ...[
                Text(
                  'Front image: ${_result!.frontImagePath.isNotEmpty ? 'yes' : 'no'}',
                ),
                Text(
                  'Back image: ${_result!.backImagePath != null ? 'yes' : 'no'}',
                ),
                const SizedBox(height: 12),
                Text('ID No: ${_result!.data.idNumber ?? ''}'),
                Text('Surname: ${_result!.data.surname ?? ''}'),
                Text('First names: ${_result!.data.firstNames ?? ''}'),
                Text('DOB: ${_result!.data.dateOfBirth?.toString() ?? ''}'),
                Text('Citizenship: ${_result!.data.citizenship ?? ''}'),
                Text(
                  'Place/Country of birth: ${_result!.data.placeOfBirth ?? ''}',
                ),
                Text('Gender: ${_result!.data.gender ?? ''}'),
                Text(
                  'Height (m): ${_result!.data.heightMeters?.toStringAsFixed(2) ?? ''}',
                ),
                Text(
                  'Date of issue: ${_result!.data.dateOfIssue?.toString() ?? ''}',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (_result!.frontImagePath.isNotEmpty)
                        Image.file(
                          File(_result!.frontImagePath),
                          fit: BoxFit.contain,
                        ),
                      if (_result!.backImagePath != null) ...[
                        const SizedBox(height: 12),
                        Image.file(
                          File(_result!.backImagePath!),
                          fit: BoxFit.contain,
                        ),
                      ],
                      if ((_result!.frontRawOcrText ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Show raw OCR text (front)'),
                          children: [SelectableText(_result!.frontRawOcrText!)],
                        ),
                      ],
                      if ((_result!.backRawOcrText ?? '').isNotEmpty) ...[
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Show raw OCR text (back)'),
                          children: [SelectableText(_result!.backRawOcrText!)],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
