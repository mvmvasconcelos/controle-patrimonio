import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Tela de teste de escaneamento com controles de diagnóstico.
/// Permite testar diferentes configurações de câmera e foco.
class BarcodeScannerTestScreen extends StatefulWidget {
  final String cancelLabel;

  const BarcodeScannerTestScreen({
    super.key,
    this.cancelLabel = 'Cancelar',
  });

  @override
  State<BarcodeScannerTestScreen> createState() =>
      _BarcodeScannerTestScreenState();
}

class _BarcodeScannerTestScreenState extends State<BarcodeScannerTestScreen> {
  late MobileScannerController _controller;
  bool _hasScanned = false;
  String _lastDetected = '';
  double _zoom = 1.0;
  late DetectionSpeed _detectionSpeed;

  @override
  void initState() {
    super.initState();
    _detectionSpeed = DetectionSpeed.normal;
    _controller = MobileScannerController(
      detectionSpeed: _detectionSpeed,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      setState(() {
        _lastDetected = barcode!.rawValue ?? '(sem valor)';
      });
      if (!_hasScanned) {
        _hasScanned = true;
        Navigator.of(context).pop(barcode!.rawValue);
      }
    }
  }

  void _resetDetection() {
    setState(() {
      _hasScanned = false;
      _lastDetected = '';
    });
  }

  Future<void> _setZoom(double value) async {
    try {
      await _controller.setZoomScale(value);
      setState(() => _zoom = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ajustar zoom: $e')),
        );
      }
    }
  }

  Future<void> _cycleDetectionSpeed() async {
    final speeds = DetectionSpeed.values;
    final currentIndex = speeds.indexOf(_detectionSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    
    setState(() {
      _detectionSpeed = speeds[nextIndex];
    });
    
    // Recreate controller with new speed
    await _controller.dispose();
    _controller = MobileScannerController(
      detectionSpeed: _detectionSpeed,
    );
    
    setState(() {
      _hasScanned = false;
      _lastDetected = 'DetectionSpeed: ${_detectionSpeed.name}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste: Escaneador'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Lanterna',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera feed
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Overlay com guia
                Center(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Controles de diagnóstico
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Última detecção
                  Text(
                    'Último detectado: $_lastDetected',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Controle de Zoom
                  Row(
                    children: [
                      const Text('Zoom:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          min: 0.5,
                          max: 5.0,
                          divisions: 18,
                          label: _zoom.toStringAsFixed(1),
                          onChanged: _setZoom,
                        ),
                      ),
                      Text(
                        '${_zoom.toStringAsFixed(1)}x',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Detection Speed
                  Row(
                    children: [
                      const Text('Velocidade:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _cycleDetectionSpeed,
                        icon: const Icon(Icons.speed),
                        label: Text(_detectionSpeed.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Reset button
                  ElevatedButton.icon(
                    onPressed: _resetDetection,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
