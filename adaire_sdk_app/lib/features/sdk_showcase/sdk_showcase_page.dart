import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_qr_scanner/flutter_barcode_qr_scanner.dart';
import 'package:flutter_id_scanner/flutter_id_scanner.dart';

import '../../core/ui/result_dialog.dart';
import '../../services/barcode_scanner_service.dart';
import '../../services/credit_card_scanner_service.dart';
import '../../services/id_scanner_service.dart';
import '../../services/passport_scanner_service.dart';
import 'sdk_showcase_item.dart';
import 'widgets/sdk_block.dart';

class SdkShowcasePage extends StatefulWidget {
  const SdkShowcasePage({super.key});

  @override
  State<SdkShowcasePage> createState() => _SdkShowcasePageState();
}

class _SdkShowcasePageState extends State<SdkShowcasePage>
    with WidgetsBindingObserver {
  final BarcodeScannerService _barcodeScanner = BarcodeScannerService();
  final CreditCardScannerService _cardScanner = CreditCardScannerService();
  final PassportScannerService _passportScanner = PassportScannerService();
  final IdScannerService _idScanner = IdScannerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op
  }

  Future<void> _openBarcodeScanner() async {
    try {
      final outcome = await _barcodeScanner.scan();
      if (!mounted) return;
      final result = outcome.result;
      final outcomeMessage = switch (outcome.type) {
        ScanOutcomeType.success =>
          'Type: ${result!.type.name}\nValue: ${result.value}',
        ScanOutcomeType.cancelled => 'Scan cancelled.',
        ScanOutcomeType.permissionDenied =>
          'Camera permission denied. Enable it in Settings and try again.',
        ScanOutcomeType.unavailable => 'Scanner unavailable.',
        ScanOutcomeType.busy => 'A scan is already in progress.',
        ScanOutcomeType.failure => 'Scan failed.',
      };
      await showResultDialog(
        context: context,
        title: 'Barcode / QR Result',
        content: outcomeMessage,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context: context,
        title: 'Scan Failed',
        content: e.message ?? 'Unknown error',
      );
    }
  }

  Future<void> _openCreditCardScanner() async {
    try {
      final result = await _cardScanner.scanCard(
        scanExpiry: true,
        // default: enable logs in debug builds
        showDetectedQuad: false,
        consensusRequired: 5,
        stabilityRequired: 3,
      );
      if (!mounted) return;

      if (result == null) {
        await showResultDialog(
          context: context,
          title: 'Credit Card',
          content: 'No data returned.',
        );
        return;
      }

      final lines = <String>[
        'Number: ${result.cardNumber}',
        'Brand: ${result.cardBrand ?? '-'}',
        'Expiry: ${result.expiryMonth ?? '-'} / ${result.expiryYear ?? '-'}',
      ];
      await showResultDialog(
        context: context,
        title: 'Credit Card Result',
        content: lines.join('\n'),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context: context,
        title: 'Scan Failed',
        content: e.message ?? 'Unknown error',
      );
    }
  }

  Future<void> _openPassportScanner() async {
    try {
      final result = await _passportScanner.scanPassport();
      if (!mounted) return;

      if (result == null) {
        await showResultDialog(
          context: context,
          title: 'Passport Scanner',
          content: 'No data returned.',
        );
        return;
      }

      final imagePath = result.imagePaths.isNotEmpty
          ? result.imagePaths.first
          : null;
      final imageUrl = imagePath == null
          ? null
          : Uri.file(imagePath).toString();

      final lines = <String>[
        // 'Image url: ${imageUrl ?? '-'}',
        // 'Image path: ${imagePath ?? '-'}',
        // 'All images: ${result.imagePaths.isEmpty ? '-' : result.imagePaths.join(', ')}',
        // 'PDF path: ${result.pdfPath ?? '-'}',
      ];

      final mrz = result.mrz;
      if (mrz == null) {
        lines.add('MRZ: not found');
      } else {
        print(mrz.toMap());

        final fullName = '${mrz.givenNames} ${mrz.surnames}'.trim();
        lines.addAll([
          'Passport name: ${fullName.isEmpty ? '-' : fullName}',
          'MRZ valid: ${mrz.isValid}',
          // 'Document code: ${mrz.documentCode}',
          'Passport #: ${mrz.passportNumber}',
          'Nationality: ${mrz.nationality}',
          'DOB: ${mrz.dateOfBirth?.toIso8601String() ?? '-'}',
          'Sex: ${mrz.sex}',
          'Expiry: ${mrz.dateOfExpiry?.toIso8601String() ?? '-'}',
          'Personal number: ${mrz.personalNumber}',
          'MRZ line 1: ${mrz.mrzLine1}',
          'MRZ line 2: ${mrz.mrzLine2}',
        ]);
        if (mrz.errors.isNotEmpty) {
          lines.add('Validation issues: ${mrz.errors.join(' | ')}');
        }
      }
      // final rawOcrText = result.rawOcrText;
      // if ((rawOcrText ?? '').trim().isNotEmpty) {
      //   lines.addAll([
      //     '--- RAW OCR TEXT ---',
      //     rawOcrText!,
      //   ]);
      // }

      await showResultDialog(
        context: context,
        title: 'Passport Result',
        content: lines.join('\n'),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context: context,
        title: 'Scan Failed',
        content: e.message ?? 'Unknown error',
      );
    }
  }

  Future<void> _openIdScanner() async {
    final progress = ValueNotifier<IdCaptureSide?>(null);
    var dialogShown = false;
    try {
      if (mounted) {
        dialogShown = true;
        // Fire-and-forget; we'll close it in finally.
        // ignore: unawaited_futures
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('ID Scanner'),
              content: ValueListenableBuilder<IdCaptureSide?>(
                valueListenable: progress,
                builder: (context, side, _) {
                  final message = switch (side) {
                    IdCaptureSide.front => 'Capture the FRONT of the ID',
                    IdCaptureSide.back => 'Capture the BACK of the ID',
                    null => 'Preparing scanner…',
                  };
                  return Text(message);
                },
              ),
            );
          },
        );
      }

      final result = await _idScanner.scanId(
        options: const IdScanOptions(
          allowGalleryImport: false,
          performOcr: true,
          returnPartialOnCancel: false,
        ),
        onProgress: (side) {
          progress.value = side;
        },
      );
      if (!mounted) return;

      if (result == null) {
        await showResultDialog(
          context: context,
          title: 'ID Scanner',
          content: 'No data returned.',
        );
        return;
      }

      final data = result.data;
      final lines = <String>[
        'ID No: ${data.idNumber ?? '-'}',
        'Surname: ${data.surname ?? '-'}',
        'First names: ${data.firstNames ?? '-'}',
        'DOB: ${data.dateOfBirth?.toString() ?? '-'}',
        'Citizenship: ${data.citizenship ?? '-'}',
        'Place/Country of birth: ${data.placeOfBirth ?? '-'}',
        'Gender: ${data.gender ?? '-'}',
        'Height (m): ${data.heightMeters?.toStringAsFixed(2) ?? '-'}',
        'Date of issue: ${data.dateOfIssue?.toString() ?? '-'}',
      ];

      await showResultDialog(
        context: context,
        title: 'ID Result',
        content: lines.join('\n'),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context: context,
        title: 'Scan Failed',
        content: e.message ?? 'Unknown error',
      );
    } finally {
      progress.dispose();
      if (dialogShown && mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
        }
      }
    }
  }

  Future<void> _showComingSoonDialog(String featureName) {
    return showResultDialog(
      context: context,
      title: featureName,
      content: 'Coming soon',
    );
  }

  Future<void> _openMultiBarcodeScanner() async {
    final results = await FlutterBarcodeQrScanner().scanMultiple(
      context: context,
      title: 'Multi Barcode/QR Scanner',
    );
    if (!mounted) return;
    if (results == null) return;

    final content = results.isEmpty
        ? 'No data returned.'
        : results
              .asMap()
              .entries
              .map(
                (e) => '${e.key + 1}. ${e.value.type.name}: ${e.value.value}',
              )
              .join('\n');

    await showResultDialog(
      context: context,
      title: 'Multi Barcode / QR Result',
      content: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <SdkItem>[
      SdkItem(
        title: 'Barcode / QR Scanner',
        icon: Icons.qr_code_scanner,
        onTap: _openBarcodeScanner,
      ),

      SdkItem(
        title: 'Multi Barcode/QR Scanner',
        icon: Icons.qr_code_scanner,
        onTap: _openMultiBarcodeScanner,
      ),

      SdkItem(
        title: 'Credit Card Scanner',
        icon: Icons.credit_card,
        onTap: _openCreditCardScanner,
      ),
      SdkItem(
        title: 'Passport Scanner',
        icon: Icons.document_scanner,
        onTap: _openPassportScanner,
      ),
      SdkItem(title: 'ID Scanner', icon: Icons.badge, onTap: _openIdScanner),
      SdkItem(
        title: 'Fingerprint Scanner',
        icon: Icons.fingerprint,
        onTap: () => _showComingSoonDialog('Fingerprint Scanner'),
      ),
      SdkItem(
        title: 'Face Recognition',
        icon: Icons.face,
        onTap: () => _showComingSoonDialog('Face Recognition'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Adaire Scan: SDK Showcase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return SdkBlock(item: item);
          },
        ),
      ),
    );
  }
}
