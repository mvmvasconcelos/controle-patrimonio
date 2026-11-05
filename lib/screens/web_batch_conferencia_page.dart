import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/batch_feedback_stub.dart'
    if (dart.library.html) '../services/batch_feedback_web.dart';
import '../services/web_inventory_repository.dart';
import 'conference_room_selection.dart';
import 'web_patrimony_pages.dart'
    show BarcodeScanner, WebPatrimonyDetailPage, errorMessage;

enum _BatchOutcome { success, duplicate, notFound, error }

class _BatchResult {
  const _BatchResult({
    required this.number,
    this.roomStatus,
    required this.message,
    required this.outcome,
  });

  final String number;
  final String? roomStatus;
  final String message;
  final _BatchOutcome outcome;
}

class WebBatchConferenciaPage extends StatefulWidget {
  const WebBatchConferenciaPage({
    super.key,
    required this.repository,
    this.scanBarcode,
    this.onFeedback,
  });

  final WebInventoryRepository repository;
  final BarcodeScanner? scanBarcode;
  final Future<void> Function(BatchFeedbackKind kind)? onFeedback;

  @override
  State<WebBatchConferenciaPage> createState() =>
      _WebBatchConferenciaPageState();
}

class _WebBatchConferenciaPageState extends State<WebBatchConferenciaPage> {
  final _number = TextEditingController();
  String? _selectedRoom;
  bool _roomDialogScheduled = false;
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _feedback = BatchFeedbackPlayer();
  final List<_BatchResult> _results = [];
  bool _busy = false;
  bool _cameraActive = false;
  bool _cameraProcessing = false;
  String? _cameraError;
  String? _feedbackError;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roomDialogScheduled) return;
    _roomDialogScheduled = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_selectRoom()));
  }

  Future<void> _selectRoom() async {
    final room = await selectConferenceRoom(context, widget.repository);
    if (mounted) setState(() => _selectedRoom = room);
  }

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

    setState(() {
      _busy = true;
      _cameraError = null;
    });

    var feedbackReady = true;
    try {
      await _feedback.prepare();
    } catch (_) {
      feedbackReady = false;
      _showFeedbackError();
    }

    if (!mounted) return;

    late final _BatchResult result;
    late final BatchFeedbackKind sound;
    String? roomStatus;
    try {
      final response = await widget.repository.markChecked(number);
      InventoryEntry? entry;
      try {
        entry = await widget.repository.fetchEntry(number);
      } catch (_) {}
      if (!mounted) return;
      if (_selectedRoom != null && entry != null) {
        if (entry.room.trim() == _selectedRoom) {
          roomStatus = 'Sala correta: ${entry.room}.';
        } else {
          roomStatus =
              'Sala divergente: cadastrada na ${entry.room.isEmpty ? 'sem Sala' : entry.room}. '
              'Sala selecionada: $_selectedRoom.';
          final correctRoom = await confirmRoomCorrection(
            context,
            number: number,
            expectedRoom: _selectedRoom!,
            actualRoom: entry.room.isEmpty ? 'sem Sala' : entry.room,
          );
          if (correctRoom && mounted) {
            await _openEntry(entry);
            try {
              final updated = await widget.repository.fetchEntry(number);
              if (updated != null && updated.room.trim() == _selectedRoom) {
                roomStatus = 'Sala corrigida para ${updated.room}.';
              }
            } catch (_) {}
          }
        }
      }
      if (response.repeated) {
        result = _BatchResult(
          number: number,
          message: 'Duplicado: Patrimônio $number já tinha uma Conferência.',
          outcome: _BatchOutcome.duplicate,
          roomStatus: roomStatus,
        );
        sound = BatchFeedbackKind.duplicate;
      } else {
        result = _BatchResult(
          number: number,
          message: 'Conferência registrada: Patrimônio $number.',
          outcome: _BatchOutcome.success,
          roomStatus: roomStatus,
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
    if (feedbackReady) {
      try {
        final onFeedback = widget.onFeedback;
        if (onFeedback != null) {
          await onFeedback(sound);
        } else {
          await _feedback.play(sound);
        }
        if (mounted && _feedbackError != null) {
          setState(() => _feedbackError = null);
        }
      } catch (_) {
        _showFeedbackError();
      }
    }
  }

  Future<void> _openEntry(InventoryEntry entry) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => WebPatrimonyDetailPage(
        repository: widget.repository,
        entry: entry,
      ),
    ));
  }

  void _showFeedbackError() {
    if (!mounted) return;
    setState(() => _feedbackError =
        'Feedback sonoro indisponível. O resultado continua visível na tela.');
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
              Text('Sala: ${_selectedRoom ?? 'Não informada'}'),
              const SizedBox(height: 12),
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
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _record(_number.text),
                icon: const Icon(Icons.search),
                label: const Text('Pesquisar manualmente'),
              ),
              const SizedBox(height: 8),
              if (_cameraAvailable && widget.scanBarcode != null)
                FilledButton.icon(
                  onPressed: _busy ? null : _scanOnce,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear'),
                )
              else if (_cameraAvailable)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _cameraActive = !_cameraActive),
                  icon:
                      Icon(_cameraActive ? Icons.videocam_off : Icons.videocam),
                  label: Text(_cameraActive ? 'Parar câmera' : 'Escanear'),
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
              if (_feedbackError != null)
                MaterialBanner(
                  content: Text(_feedbackError!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _feedbackError = null),
                      child: const Text('Dispensar'),
                    ),
                  ],
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patrimônio ${result.number}'),
                      if (result.roomStatus != null)
                        Text(
                          result.roomStatus!,
                          style: TextStyle(
                            color: result.roomStatus!.startsWith('Sala correta')
                                ? Colors.green.shade700
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
