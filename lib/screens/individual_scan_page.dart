import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/patrimonio_provider.dart';
import '../models/patrimonio.dart';
import '../utils/feedback_utils.dart';
import '../widgets/scanned_item_modal.dart';
import '../widgets/barcode_scanner_screen.dart';

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
      body: SingleChildScrollView(
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
                    label: const Text('Pesquisar manualmente'),
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
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_patrimonioEncontrado != null)
              _buildPatrimonioCard()
            else
              const Padding(
                padding: EdgeInsets.only(top: 48),
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

    return Card(
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
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                    onPressed: _limparBusca,
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

            const SizedBox(height: 16),

            // Botões de ação
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _editarPatrimonio(context, patrimonio),
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
              ),
            ),
          ],
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
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(cancelLabel: 'Cancelar'),
        ),
      );

      if (result != null && mounted) {
        await FeedbackUtils.provideHapticFeedback();
        await FeedbackUtils.provideSoundFeedback();
        _numeroController.text = result;
        _buscarPatrimonio(result);
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
    
    // Calcular mudanças
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

      // Atualizar a visualização
      setState(() {
        _patrimonioEncontrado = updated;
      });
    }
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
                _registrarNovoItem(numero);
              },
              child: const Text('Registrar Novo'),
            ),
          ],
        );
      },
    );
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
      isModified: true, // Novo item criado offline é modificado por definição
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
          
          setState(() {
            _patrimonioEncontrado = patrimonioSalvo;
            _numeroController.text = numero;
          });

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