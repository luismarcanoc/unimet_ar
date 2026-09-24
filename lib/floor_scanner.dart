import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'floor_markers.dart';

class FloorScannerScreen extends StatefulWidget {
  const FloorScannerScreen({super.key});
  @override
  State<FloorScannerScreen> createState() => _FloorScannerScreenState();
}

class _FloorScannerScreenState extends State<FloorScannerScreen> {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  AppLifecycleListener? _lifecycle;
  bool _finishing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _start,
      onInactive: () => unawaited(_controller.stop()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_finishing || !mounted) return;
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir la cámara. Revisa el permiso.',
        );
      }
    }
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_finishing) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      final marker = parseFloorMarker(value);
      if (marker == null) {
        if (mounted &&
            _error !=
                'Este QR no corresponde a los pisos registrados de UNIMET.') {
          setState(
            () => _error =
                'Este QR no corresponde a los pisos registrados de UNIMET.',
          );
        }
        continue;
      }
      _finishing = true;
      await _controller.stop();
      if (mounted) Navigator.of(context).pop(marker);
      return;
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Identificar piso')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _detected,
          errorBuilder: (context, error) => Center(
            child: Text('Cámara no disponible: ${error.errorCode.name}'),
          ),
        ),
        if (_error != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(24),
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            ),
          ),
      ],
    ),
  );
}
