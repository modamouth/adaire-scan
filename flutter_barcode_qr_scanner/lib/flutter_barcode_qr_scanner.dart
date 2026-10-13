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

/// Formats approved for the Android private-evaluation candidate.
const Set<BarcodeFormat> supportedBarcodeFormats = <BarcodeFormat>{
  BarcodeFormat.qr,
  BarcodeFormat.ean13,
  BarcodeFormat.code128,
};

enum ScanOutcomeType {
  success,
  cancelled,
  permissionDenied,
  unavailable,
  busy,
  failure,
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
  String toString() => 'ScanResult(type: ${type.name}, value: <redacted>)';
}

/// One terminal result from a scan attempt.
///
/// Decoded content is available only through [result] after [type] is
/// [ScanOutcomeType.success]. Diagnostic codes are stable machine-readable
/// identifiers and never include decoded content.
class ScanOutcome {
  final ScanOutcomeType type;
  final ScanResult? result;
  final String? diagnosticCode;

  const ScanOutcome._({required this.type, this.result, this.diagnosticCode});

  const ScanOutcome.success(ScanResult result)
    : this._(type: ScanOutcomeType.success, result: result);

  const ScanOutcome.cancelled() : this._(type: ScanOutcomeType.cancelled);

  const ScanOutcome.permissionDenied()
    : this._(type: ScanOutcomeType.permissionDenied);

  const ScanOutcome.unavailable({String? diagnosticCode})
    : this._(type: ScanOutcomeType.unavailable, diagnosticCode: diagnosticCode);

  const ScanOutcome.busy() : this._(type: ScanOutcomeType.busy);

  const ScanOutcome.failure({String? diagnosticCode})
    : this._(type: ScanOutcomeType.failure, diagnosticCode: diagnosticCode);

  bool get isSuccess => type == ScanOutcomeType.success;

  @override
  String toString() =>
      'ScanOutcome(type: ${type.name}, diagnosticCode: $diagnosticCode, '
      'result: ${result == null ? 'none' : '<redacted>'})';

  static ScanOutcome fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ScanOutcome.failure(
        diagnosticCode: 'malformed_native_result',
      );
    }

    final outcome = map['outcome'];
    if (outcome is! String) {
      return const ScanOutcome.failure(
        diagnosticCode: 'malformed_native_result',
      );
    }

    switch (outcome) {
      case 'success':
        final value = map['value'];
        final typeKey = map['type'];
        if (value is! String ||
            value.isEmpty ||
            typeKey is! String ||
            !supportedBarcodeFormats.contains(barcodeFormatFromKey(typeKey))) {
          return const ScanOutcome.failure(
            diagnosticCode: 'malformed_native_result',
          );
        }
        return ScanOutcome.success(
          ScanResult(value: value, type: barcodeFormatFromKey(typeKey)),
        );
      case 'cancelled':
        return const ScanOutcome.cancelled();
      case 'permission_denied':
        return const ScanOutcome.permissionDenied();
      case 'unavailable':
        return ScanOutcome.unavailable(diagnosticCode: _diagnosticCode(map));
      case 'busy':
        return const ScanOutcome.busy();
      case 'failure':
        return ScanOutcome.failure(diagnosticCode: _diagnosticCode(map));
      default:
        return const ScanOutcome.failure(
          diagnosticCode: 'malformed_native_result',
        );
    }
  }

  static String? _diagnosticCode(Map<String, dynamic> map) {
    final code = map['diagnosticCode'];
    const allowedCodes = <String>{
      'no_activity',
      'launch_failed',
      'engine_detached',
      'activity_detached',
      'invalid_formats',
      'malformed_activity_result',
    };
    if (code == null) return null;
    return code is String && allowedCodes.contains(code)
        ? code
        : 'native_failure';
  }
}

class FlutterBarcodeQrScanner {
  Future<String?> getPlatformVersion() {
    return FlutterBarcodeQrScannerPlatform.instance.getPlatformVersion();
  }

  /// Opens the native scanner UI and returns one typed terminal outcome.
  ///
  /// If [formats] is omitted, the approved QR, EAN-13, and Code 128 set is
  /// used. Empty or unsupported requests fail without launching the scanner.
  Future<ScanOutcome> scan({List<BarcodeFormat>? formats}) async {
    final requested = formats ?? supportedBarcodeFormats.toList();
    if (requested.isEmpty) {
      return const ScanOutcome.failure(diagnosticCode: 'invalid_formats');
    }
    if (requested.any((format) => !supportedBarcodeFormats.contains(format))) {
      return const ScanOutcome.failure(diagnosticCode: 'unsupported_format');
    }

    final formatKeys = requested.map(_formatToKey).toSet().toList();
    try {
      final map = await FlutterBarcodeQrScannerPlatform.instance.scan(
        formats: formatKeys,
      );
      return ScanOutcome.fromMap(map);
    } on PlatformException {
      return const ScanOutcome.failure(diagnosticCode: 'transport_failure');
    } catch (_) {
      return const ScanOutcome.failure(diagnosticCode: 'transport_failure');
    }
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
      final outcome = await _scanner.scan(formats: widget.formats);
      if (!mounted) return;

      if (!outcome.isSuccess) {
        if (outcome.type != ScanOutcomeType.cancelled) {
          final message = switch (outcome.type) {
            ScanOutcomeType.permissionDenied => 'Camera permission denied',
            ScanOutcomeType.unavailable => 'Scanner unavailable',
            ScanOutcomeType.busy => 'A scan is already in progress',
            ScanOutcomeType.failure => 'Scan failed',
            ScanOutcomeType.cancelled => 'Scan cancelled',
            ScanOutcomeType.success => 'Scan completed',
          };
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }

      final result = outcome.result!;

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
