import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../shared/theme/app_colors.dart';

class BloquesQrScannerView extends StatefulWidget {
  const BloquesQrScannerView({super.key});

  @override
  State<BloquesQrScannerView> createState() => _BloquesQrScannerViewState();
}

class _BloquesQrScannerViewState extends State<BloquesQrScannerView> {
  bool _returned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      appBar: AppBar(
        title: const Text('Escanear bloque'),
        backgroundColor: AppColors.deepBlack,
        foregroundColor: AppColors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returned || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    _returned = true;
    Navigator.of(context).pop(value);
  }
}
