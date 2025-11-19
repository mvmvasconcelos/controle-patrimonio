import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/patrimonio_provider.dart';
import '../models/patrimonio.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../utils/feedback_utils.dart';

class IndividualScanPage extends StatefulWidget {
  final String? selectedSala;

  const IndividualScanPage({super.key, required this.selectedSala});

  @override
  State<IndividualScanPage> createState() => _IndividualScanPageState();
}

class _IndividualScanPageState extends State<IndividualScanPage> {
  final TextEditingController _numeroController = TextEditingController();
  Patrimonio? _patrimonioEncontrado;
  bool _isLoading = false;

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escaneamento Individual'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sala selecionada
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                            Text(
                              'Sala: ${widget.selectedSala ?? 'Não informada'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Campo para digitar o número do patrimônio
            TextField(
              controller: _numeroController,
              decoration: const InputDecoration(
                labelText: 'Número do Patrimônio',
                hintText: 'Digite ou escaneie o código',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: _buscarPatrimonio,
            ),

            const SizedBox(height: 16),

            // Botões
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _buscarPatrimonio(_numeroController.text),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _abrirScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Resultado da busca
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_patrimonioEncontrado != null)
              _buildPatrimonioCard()
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Digite o número do patrimônio ou use o scanner',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatrimonioCard() {
  final patrimonio = _patrimonioEncontrado!;
  // Se o usuário não informou uma sala (null), não marcamos como diferente
  final isSalaDiferente = widget.selectedSala != null && patrimonio.sala != widget.selectedSala;

    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory, color: Colors.blue, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Patrimônio ${patrimonio.numeroPatrimonio}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Campo Sala com destaque se diferente
              _buildFieldWithHighlight(
                label: 'Sala',
                value: patrimonio.sala,
                highlight: isSalaDiferente,
                highlightColor: Colors.orange,
              ),

              _buildField('Descrição', patrimonio.descricao),
              _buildField('Responsável', patrimonio.responsavel),
              _buildField('Situação', patrimonio.situacao),

              if (patrimonio.observacoes != null && patrimonio.observacoes!.isNotEmpty)
                _buildField('Observações', patrimonio.observacoes!),

              const Spacer(),

              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _limparBusca,
                      icon: const Icon(Icons.clear),
                      label: const Text('Novo'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editarPatrimonio(context, patrimonio),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWithHighlight({
    required String label,
    required String value,
    required bool highlight,
    required Color highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        border: Border.all(
          color: highlight ? highlightColor : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        color: highlight ? highlightColor.withOpacity(0.1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? highlightColor : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
          if (highlight) ...[
            const SizedBox(height: 4),
            Text(
              '⚠️ Sala diferente da selecionada',
              style: TextStyle(
                color: highlightColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _buscarPatrimonio(String numero) {
    if (numero.isEmpty) return;

    setState(() {
      _isLoading = true;
      _patrimonioEncontrado = null;
    });

    final provider = context.read<PatrimonioProvider>();
    final patrimonio = provider.getPatrimonioByNumero(numero.trim());

    setState(() {
      _isLoading = false;
      _patrimonioEncontrado = patrimonio;
    });

    if (patrimonio == null) {
      _mostrarDialogNaoEncontrado(numero);
    }
  }

  Future<void> _abrirScanner() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#1B5E20', 'Cancelar', true, ScanMode.BARCODE);

      if (barcodeScanRes != '-1') {
        await FeedbackUtils.provideHapticFeedback();
        await FeedbackUtils.provideSoundFeedback();
        _numeroController.text = barcodeScanRes;
        _buscarPatrimonio(barcodeScanRes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir scanner: $e')),
        );
      }
    }
  }

  void _limparBusca() {
    setState(() {
      _numeroController.clear();
      _patrimonioEncontrado = null;
    });
  }

  void _editarPatrimonio(BuildContext context, Patrimonio patrimonio) {
    // TODO: Implementar modal de edição
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edição será implementada na próxima etapa')),
    );
  }

  void _mostrarDialogNaoEncontrado(String numero) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Patrimônio não encontrado'),
          content: Text(
            'O patrimônio "$numero" não foi encontrado na base de dados.\n\n'
            'Deseja tentar novamente ou registrar um novo item?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tentar Novamente'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implementar registro de novo item
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registro de novo item será implementado')),
                );
              },
              child: const Text('Registrar Novo'),
            ),
          ],
        );
      },
    );
  }
}