import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flutter_barcode_qr_scanner_platform_interface.dart';

/// Barcode formats supported across platforms.
/// Keys align with native mappings.
enum BarcodeFormat {
  qr,
  ean13,
  ean8,
  code128,
  code39,
  code93,
  upca,
  upce,
  itf,
  codabar,
  datamatrix,
  aztec,
  pdf417,
  unknown,
}

String _formatToKey(BarcodeFormat f) => f.name;

BarcodeFormat barcodeFormatFromKey(String? key) {
  switch (key) {
    case 'qr':
      return BarcodeFormat.qr;
    case 'ean13':
      return BarcodeFormat.ean13;
    case 'ean8':
      return BarcodeFormat.ean8;
    case 'code128':
      return BarcodeFormat.code128;
    case 'code39':
      return BarcodeFormat.code39;
    case 'code93':
      return BarcodeFormat.code93;
    case 'upca':
      return BarcodeFormat.upca;
    case 'upce':
      return BarcodeFormat.upce;
    case 'itf':
      return BarcodeFormat.itf;
    case 'codabar':
      return BarcodeFormat.codabar;
    case 'datamatrix':
      return BarcodeFormat.datamatrix;
    case 'aztec':
      return BarcodeFormat.aztec;
    case 'pdf417':
      return BarcodeFormat.pdf417;
    default:
      return BarcodeFormat.unknown;
  }
}

class ScanResult {
  final String value;
  final BarcodeFormat type;

  const ScanResult({required this.value, required this.type});

  @override
  String toString() => 'ScanResult(value: $value, type: ${type.name})';

  static ScanResult? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final value = map['value']?.toString();
    if (value == null) return null;
    final type = barcodeFormatFromKey(map['type']?.toString());
    return ScanResult(value: value, type: type);
  }
}

class FlutterBarcodeQrScanner {
  Future<String?> getPlatformVersion() {
    return FlutterBarcodeQrScannerPlatform.instance.getPlatformVersion();
  }

  /// Opens the native scanner UI and returns the first detected barcode.
  ///
  /// Optionally filter by [formats]. If omitted, scans all supported formats.
  Future<ScanResult?> scan({List<BarcodeFormat>? formats}) async {
    final formatKeys = formats?.map(_formatToKey).toList();
    final map = await FlutterBarcodeQrScannerPlatform.instance.scan(
      formats: formatKeys,
    );
    return ScanResult.fromMap(map);
  }

  /// Opens a multi-scan UI that keeps scanning until the user taps **Done**.
  ///
  /// - Duplicate values are ignored and show a brief "already taken" message.
  /// - Returns the accumulated list (or `null` if the page was dismissed).
  ///
  /// Note: This uses Material UI (`Scaffold`, `SnackBar`).
  Future<List<ScanResult>?> scanMultiple({
    required BuildContext context,
    List<BarcodeFormat>? formats,
    bool initialAutoContinue = false,
    String title = 'Multi Barcode/QR Scanner',
  }) {
    return Navigator.of(context).push<List<ScanResult>>(
      MaterialPageRoute(
        builder: (_) => MultiBarcodeQrScannerPage(
          formats: formats,
          initialAutoContinue: initialAutoContinue,
          title: title,
        ),
      ),
    );
  }
}

/// A Material page that repeatedly opens the native scanner and accumulates
/// unique results until the user taps **Done**.
class MultiBarcodeQrScannerPage extends StatefulWidget {
  final List<BarcodeFormat>? formats;
  final bool initialAutoContinue;
  final String title;

  const MultiBarcodeQrScannerPage({
    super.key,
    this.formats,
    this.initialAutoContinue = false,
    this.title = 'Multi Barcode/QR Scanner',
  });

  @override
  State<MultiBarcodeQrScannerPage> createState() =>
      _MultiBarcodeQrScannerPageState();
}

class _MultiBarcodeQrScannerPageState extends State<MultiBarcodeQrScannerPage> {
  final FlutterBarcodeQrScanner _scanner = FlutterBarcodeQrScanner();

  final List<ScanResult> _results = <ScanResult>[];
  final Set<String> _seenKeys = <String>{};

  var _isScanning = false;
  late bool _autoContinue;

  @override
  void initState() {
    super.initState();
    _autoContinue = widget.initialAutoContinue;
  }

  Future<void> _scanNext() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await _scanner.scan(formats: widget.formats);
      if (!mounted) return;

      if (result == null) return;

      final value = result.value.trim();
      if (value.isEmpty) return;

      final key = '${result.type.name}|$value';

      if (_seenKeys.contains(key)) {
        final message = result.type == BarcodeFormat.qr
            ? 'QR already taken'
            : 'Barcode already taken';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      setState(() {
        _seenKeys.add(key);
        _results.add(ScanResult(value: value, type: result.type));
      });

      if (_autoContinue) {
        // Reopen the scanner UI after a successful unique scan.
        // ignore: unawaited_futures
        Future<void>.delayed(const Duration(milliseconds: 150), _scanNext);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Scan failed')));
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _removeAt(int index) {
    final removed = _results.removeAt(index);
    _seenKeys.remove('${removed.type.name}|${removed.value}');
    setState(() {});
  }

  void _clearAll() {
    setState(() {
      _results.clear();
      _seenKeys.clear();
    });
  }

  void _done() {
    Navigator.of(
      context,
    ).pop<List<ScanResult>>(List<ScanResult>.unmodifiable(_results));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed: _results.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton(onPressed: _done, child: const Text('Done')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Scan multiple codes. Duplicate scans are ignored.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SwitchListTile.adaptive(
            value: _autoContinue,
            onChanged: (v) {
              setState(() {
                _autoContinue = v;
              });
            },
            title: const Text('Auto-continue scanning'),
            subtitle: const Text(
              'Automatically reopens scanner after each unique scan.',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No scans yet. Tap Scan to start.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          leading: Icon(
                            r.type == BarcodeFormat.qr
                                ? Icons.qr_code
                                : Icons.view_week,
                          ),
                          title: Text(r.type.name.toUpperCase()),
                          subtitle: SelectableText(r.value),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            onPressed: () => _removeAt(index),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isScanning ? null : _scanNext,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_isScanning ? 'Scanning…' : 'Scan'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
