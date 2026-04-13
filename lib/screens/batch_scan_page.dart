import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/patrimonio_provider.dart';
import '../models/patrimonio.dart';
import '../widgets/scanned_item_modal.dart';
import '../utils/feedback_utils.dart';
import '../widgets/barcode_scanner_screen.dart';

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
                          label: const Text('Pesquisar manualmente'),
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
                    child: Consumer<PatrimonioProvider>(
                      builder: (context, provider, child) {
                        return ListView.builder(
                          itemCount: _scannedItems.length,
                          itemBuilder: (context, index) {
                            final numero = _scannedItems[index];
                            final patrimonio = provider.getPatrimonioByNumero(numero);
                            
                            // Determine status and colors
                            final bool isFound = patrimonio != null;
                            final bool isCorrectRoom = isFound && 
                                (widget.selectedSala == null || patrimonio.sala == widget.selectedSala);
                            
                            Color statusColor;
                            IconData statusIcon;
                            
                            if (!isFound) {
                              statusColor = Colors.grey;
                              statusIcon = Icons.help_outline;
                            } else if (isCorrectRoom) {
                              statusColor = Colors.green;
                              statusIcon = Icons.check_circle;
                            } else {
                              statusColor = Colors.orange;
                              statusIcon = Icons.warning_amber_rounded;
                            }

                            return Dismissible(
                              key: Key(numero),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                _removeItem(index);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Item $numero removido da lista'),
                                    action: SnackBarAction(
                                      label: 'Desfazer',
                                      onPressed: () {
                                        setState(() {
                                          _scannedItems.insert(index, numero);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: statusColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    if (isFound) {
                                      _editarPatrimonio(context, patrimonio);
                                    } else {
                                      _registrarNovoItem(numero);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(statusIcon, color: statusColor),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Patrimônio $numero',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (isFound) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  patrimonio.descricao,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.room, size: 14, color: Colors.grey[500]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      patrimonio.sala,
                                                      style: TextStyle(
                                                        color: isCorrectRoom ? Colors.grey[600] : Colors.orange,
                                                        fontWeight: isCorrectRoom ? FontWeight.normal : FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ] else
                                                const Text(
                                                  'Não encontrado - Toque para registrar',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontStyle: FontStyle.italic,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(cancelLabel: 'Parar'),
        ),
      );

      if (result == null) {
        // Usuário cancelou
        setState(() {
          _isScanning = false;
        });
        return;
      }

      if (mounted) {
        if (_scannedItems.contains(result)) {
          // Duplicado: não adicionar, apenas feedback diferente
          await FeedbackUtils.provideHapticFeedback();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item já escaneado')),
          );
        } else {
          setState(() {
            _scannedItems.add(result);
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
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(cancelLabel: 'Parar'),
        ),
      );

      if (result == null) return; // cancelado

      if (!mounted) return;

      if (_scannedItems.contains(result)) {
        await FeedbackUtils.provideHapticFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item já escaneado')),
        );
        return;
      }

      setState(() {
        _scannedItems.add(result);
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
  void _editarPatrimonio(BuildContext context, Patrimonio patrimonio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScannedItemModal(
        patrimonio: patrimonio,
        selectedSala: widget.selectedSala,
        onSave: (updatedPatrimonio) {
          _salvarAlteracoes(patrimonio, updatedPatrimonio);
        },
      ),
    );
  }

  void _salvarAlteracoes(Patrimonio original, Patrimonio updated) {
    final provider = context.read<PatrimonioProvider>();
    
    final changes = <String, dynamic>{};
    if (original.descricao != updated.descricao) changes['descricao'] = updated.descricao;
    if (original.sala != updated.sala) changes['sala'] = updated.sala;
    if (original.responsavel != updated.responsavel) changes['responsavel'] = updated.responsavel;
    if (original.situacao != updated.situacao) changes['situacao'] = updated.situacao;
    if (original.observacoes != updated.observacoes) changes['observacoes'] = updated.observacoes;

    if (changes.isNotEmpty) {
      provider.updatePatrimonio(original, changes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alterações salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _registrarNovoItem(String numero) {
    final novoPatrimonio = Patrimonio(
      numeroPatrimonio: numero,
      descricao: '',
      sala: widget.selectedSala ?? '',
      responsavel: '',
      situacao: 'Bom',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isModified: true,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScannedItemModal(
        patrimonio: novoPatrimonio,
        selectedSala: widget.selectedSala,
        onSave: (patrimonioSalvo) {
          context.read<PatrimonioProvider>().addPatrimonio(patrimonioSalvo);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novo item registrado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}