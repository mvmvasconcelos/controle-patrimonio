import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/batch_feedback_stub.dart'
    if (dart.library.html) '../services/batch_feedback_web.dart';
import '../services/web_inventory_repository.dart';
import 'web_patrimony_pages.dart' show BarcodeScanner, errorMessage;

enum _BatchOutcome { success, duplicate, notFound, error }

class _BatchResult {
  const _BatchResult({
    required this.number,
    required this.message,
    required this.outcome,
  });

  final String number;
  final String message;
  final _BatchOutcome outcome;
}

class WebBatchConferenciaPage extends StatefulWidget {
  const WebBatchConferenciaPage({
    super.key,
    required this.repository,
    this.scanBarcode,
  });

  final WebInventoryRepository repository;
  final BarcodeScanner? scanBarcode;

  @override
  State<WebBatchConferenciaPage> createState() =>
      _WebBatchConferenciaPageState();
}

class _WebBatchConferenciaPageState extends State<WebBatchConferenciaPage> {
  final _number = TextEditingController();
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _feedback = BatchFeedbackPlayer();
  final List<_BatchResult> _results = [];
  bool _busy = false;
  bool _cameraActive = false;
  bool _cameraProcessing = false;
  String? _cameraError;

  bool get _cameraAvailable =>
      !kIsWeb ||
      Uri.base.scheme == 'https' ||
      Uri.base.host == 'localhost' ||
      Uri.base.host == '127.0.0.1';

  @override
  void dispose() {
    _number.dispose();
    _scanner.dispose();
    unawaited(_feedback.dispose());
    super.dispose();
  }

  Future<void> _record(String raw) async {
    final number = raw.trim();
    if (number.isEmpty || _busy) return;

    try {
      await _feedback.prepare();
    } catch (_) {
      // Browser audio can be unavailable while visual feedback remains usable.
    }

    if (!mounted) return;
    setState(() {
      _busy = true;
      _cameraError = null;
    });

    late final _BatchResult result;
    late final BatchFeedbackKind sound;
    try {
      final response = await widget.repository.markChecked(number);
      if (response.repeated) {
        result = _BatchResult(
          number: number,
          message: 'Duplicado: Patrimônio $number já tinha uma Conferência.',
          outcome: _BatchOutcome.duplicate,
        );
        sound = BatchFeedbackKind.duplicate;
      } else {
        result = _BatchResult(
          number: number,
          message: 'Conferência registrada: Patrimônio $number.',
          outcome: _BatchOutcome.success,
        );
        sound = BatchFeedbackKind.success;
      }
    } on PatrimonyNotFoundException {
      result = _BatchResult(
        number: number,
        message: 'Não encontrado: Patrimônio $number não está no Inventário.',
        outcome: _BatchOutcome.notFound,
      );
      sound = BatchFeedbackKind.notFound;
    } catch (error) {
      result = _BatchResult(
        number: number,
        message: 'Erro ao conferir Patrimônio $number: ${errorMessage(error)}',
        outcome: _BatchOutcome.error,
      );
      sound = BatchFeedbackKind.error;
    }

    if (!mounted) return;
    setState(() {
      _results.insert(0, result);
      _number.clear();
      _busy = false;
    });
    try {
      await _feedback.play(sound);
    } catch (_) {
      // Audio feedback must not hide the API result.
    }
  }

  Future<void> _scanOnce() async {
    try {
      final number = await widget.scanBarcode!(context);
      if (number != null) await _record(number);
    } catch (error) {
      if (mounted) setState(() => _cameraError = errorMessage(error));
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_cameraProcessing || _busy) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;

    _cameraProcessing = true;
    unawaited(_record(value).whenComplete(() {
      _cameraProcessing = false;
    }));
  }

  Color _color(_BatchOutcome outcome, ColorScheme colors) => switch (outcome) {
        _BatchOutcome.success => Colors.green.shade700,
        _BatchOutcome.duplicate => Colors.orange.shade800,
        _BatchOutcome.notFound => colors.error,
        _BatchOutcome.error => colors.error,
      };

  IconData _icon(_BatchOutcome outcome) => switch (outcome) {
        _BatchOutcome.success => Icons.check_circle,
        _BatchOutcome.duplicate => Icons.content_copy,
        _BatchOutcome.notFound => Icons.search_off,
        _BatchOutcome.error => Icons.error,
      };

  @override
  Widget build(BuildContext context) {
    final resultCount = _results.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Conferência em lote')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _number,
                autofocus: true,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Número do patrimônio',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _record,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : () => _record(_number.text),
                icon: const Icon(Icons.fact_check),
                label: const Text('Registrar Conferência'),
              ),
              const SizedBox(height: 8),
              if (_cameraAvailable && widget.scanBarcode != null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _scanOnce,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear com a câmera'),
                )
              else if (_cameraAvailable)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _cameraActive = !_cameraActive),
                  icon:
                      Icon(_cameraActive ? Icons.videocam_off : Icons.videocam),
                  label:
                      Text(_cameraActive ? 'Parar câmera' : 'Iniciar câmera'),
                )
              else
                const Text('A câmera exige HTTPS. Use a digitação manual.'),
              if (_cameraActive && widget.scanBarcode == null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MobileScanner(
                      controller: _scanner,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
                const Text(
                    'Aponte para um código por vez e aguarde o feedback.'),
              ],
              if (_cameraError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Falha na câmera: $_cameraError',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                  '$resultCount ${resultCount == 1 ? 'resultado' : 'resultados'} nesta sessão'),
              const Divider(),
              for (final result in _results)
                ListTile(
                  leading: Icon(
                    _icon(result.outcome),
                    color:
                        _color(result.outcome, Theme.of(context).colorScheme),
                  ),
                  title: Text(result.message),
                  subtitle: Text('Patrimônio ${result.number}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
