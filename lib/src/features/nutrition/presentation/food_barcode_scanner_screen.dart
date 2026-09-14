import 'package:cycle_ready/src/features/nutrition/application/food_catalogue_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FoodBarcodeScannerScreen extends ConsumerStatefulWidget {
  const FoodBarcodeScannerScreen({super.key});

  @override
  ConsumerState<FoodBarcodeScannerScreen> createState() =>
      _FoodBarcodeScannerScreenState();
}

class _FoodBarcodeScannerScreenState
    extends ConsumerState<FoodBarcodeScannerScreen> {
  late final MobileScannerController scanner = MobileScannerController(
    formats: const [
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );
  bool lookingUp = false;
  String? scannedCode;
  String? message;

  @override
  void dispose() {
    scanner.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (lookingUp) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => RegExp(r'^\d{8,14}$').hasMatch(value))
        .firstOrNull;
    if (code == null) return;
    setState(() {
      lookingUp = true;
      scannedCode = code;
      message = null;
    });
    await scanner.stop();
    final product =
        await ref.read(foodCatalogueRepositoryProvider).findBarcode(code);
    if (!mounted) return;
    if (product != null) {
      Navigator.pop(context, product);
      return;
    }
    setState(() {
      lookingUp = false;
      message = 'This barcode is not in Open Food Facts yet.';
    });
  }

  Future<void> _scanAgain() async {
    setState(() {
      scannedCode = null;
      message = null;
    });
    await scanner.start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan food barcode'),
          actions: [
            IconButton(
              tooltip: 'Torch',
              onPressed: scanner.toggleTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
            ),
          ],
        ),
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: scanner, onDetect: _detected),
          Center(
            child: Container(
              width: 300,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              color: Colors.black87,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (lookingUp) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text('Finding product $scannedCodeâ€¦',
                      style: const TextStyle(color: Colors.white)),
                ] else ...[
                  Text(
                    message ?? 'Hold the packet barcode inside the frame.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _scanAgain,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan another barcode'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Search by name instead'),
                    ),
                  ],
                ],
              ]),
            ),
          ),
        ]),
      );
}
