import 'package:flutter/material.dart';

class BatchScanPage extends StatefulWidget {
  final String selectedSala;

  const BatchScanPage({super.key, required this.selectedSala});

  @override
  State<BatchScanPage> createState() => _BatchScanPageState();
}

class _BatchScanPageState extends State<BatchScanPage> {
  final List<String> _scannedItems = [];
  bool _isScanning = false;

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
                  'Sala: ${widget.selectedSala}',
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

          // Área do scanner
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isScanning ? Icons.qr_code_scanner : Icons.qr_code,
                      size: 100,
                      color: _isScanning ? Colors.green : Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isScanning ? 'Escaneando...' : 'Scanner não implementado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _toggleScanning,
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                      label: Text(_isScanning ? 'Parar' : 'Iniciar Scanner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
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
      // Simular escaneamento para demonstração
      _simulateScanning();
    }
  }

  void _simulateScanning() {
    // Simulação de escaneamento - será substituído pelo scanner real
    Future.delayed(const Duration(seconds: 2), () {
      if (_isScanning && mounted) {
        final numero = 'PAT${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        setState(() {
          _scannedItems.add(numero);
        });
        // Continuar escaneando
        _simulateScanning();
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
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