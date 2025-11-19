import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../utils/feedback_utils.dart';

class BatchScanPage extends StatefulWidget {
  final String? selectedSala;

  const BatchScanPage({super.key, required this.selectedSala});

  @override
  State<BatchScanPage> createState() => _BatchScanPageState();
}

class _BatchScanPageState extends State<BatchScanPage> {
  final List<String> _scannedItems = [];
  bool _isScanning = false;
  final TextEditingController _numeroController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escaneamento em Lotes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (_scannedItems.isNotEmpty)
            TextButton(
              onPressed: _finishScanning,
              child: const Text(
                'Finalizar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header com sala selecionada
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                Text(
                  'Sala: ${widget.selectedSala ?? 'Não informada'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_scannedItems.length} itens escaneados',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Área de entrada manual e botão de escaneamento (UI similar ao individual)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _numeroController,
                    decoration: const InputDecoration(
                      labelText: 'Número do Patrimônio',
                      hintText: 'Digite ou escaneie o código',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _addManual(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addManual,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanOnce,
                        icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
                        label: Text(_isScanning ? 'Parar' : 'Escanear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isScanning)
                    Center(
                      child: Column(
                        children: const [
                          SizedBox(height: 8),
                          Text('Escaneando...'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Lista de itens escaneados
          if (_scannedItems.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Itens Escaneados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _scannedItems.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.inventory),
                          title: Text('Patrimônio ${_scannedItems[index]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
    });

    if (_isScanning) {
      _startBatchScan();
    }
  }

  Future<void> _startBatchScan() async {
    if (!_isScanning) return;

    try {
      // O scanner fecha após cada leitura, então chamamos recursivamente
      // para simular um lote até que o usuário cancele
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#1B5E20', 'Parar', true, ScanMode.BARCODE);

      if (barcodeScanRes == '-1') {
        // Usuário cancelou
        setState(() {
          _isScanning = false;
        });
        return;
      }

      if (mounted) {
        if (_scannedItems.contains(barcodeScanRes)) {
          // Duplicado: não adicionar, apenas feedback diferente
          await FeedbackUtils.provideHapticFeedback();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item já escaneado')),
          );
        } else {
          setState(() {
            _scannedItems.add(barcodeScanRes);
          });

          await FeedbackUtils.provideHapticFeedback();
          await FeedbackUtils.provideSoundFeedback();
        }

        // Continuar escaneando se ainda estiver no modo de escaneamento
        if (_isScanning) {
          _startBatchScan();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no scanner: $e')),
        );
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // Escaneia uma vez (usado pelo botão Escanear quando não em modo contínuo)
  Future<void> _scanOnce() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#1B5E20', 'Parar', true, ScanMode.BARCODE);

      if (barcodeScanRes == '-1') return; // cancelado

      if (!mounted) return;

      if (_scannedItems.contains(barcodeScanRes)) {
        await FeedbackUtils.provideHapticFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item já escaneado')),
        );
        return;
      }

      setState(() {
        _scannedItems.add(barcodeScanRes);
      });

      await FeedbackUtils.provideHapticFeedback();
      await FeedbackUtils.provideSoundFeedback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no scanner: $e')),
        );
      }
    }
  }

  // Adicionar manualmente via campo de texto
  void _addManual() {
    final value = _numeroController.text.trim();
    if (value.isEmpty) return;

    if (_scannedItems.contains(value)) {
      FeedbackUtils.provideHapticFeedback();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item já escaneado')),
      );
      return;
    }

    setState(() {
      _scannedItems.add(value);
      _numeroController.clear();
    });

    FeedbackUtils.provideHapticFeedback();
    FeedbackUtils.provideSoundFeedback();
  }

  void _removeItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
  }

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  void _finishScanning() {
    if (_scannedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Finalizar Escaneamento'),
          content: Text(
            'Foram escaneados ${_scannedItems.length} itens.\n\n'
            'Deseja revisar a lista antes de finalizar?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Revisar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implementar navegação para tela de revisão
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_scannedItems.length} itens escaneados com sucesso!'),
                  ),
                );
                Navigator.of(context).pop(); // Voltar para tela principal
              },
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }
}