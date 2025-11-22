import 'package:flutter/material.dart';
import '../models/patrimonio.dart';

class ScannedItemModal extends StatefulWidget {
  final Patrimonio patrimonio;
  final String? selectedSala;
  final Function(Patrimonio) onSave;

  const ScannedItemModal({
    super.key,
    required this.patrimonio,
    this.selectedSala,
    required this.onSave,
  });

  @override
  State<ScannedItemModal> createState() => _ScannedItemModalState();
}

class _ScannedItemModalState extends State<ScannedItemModal> {
  late TextEditingController _descricaoController;
  late TextEditingController _salaController;
  late TextEditingController _responsavelController;
  late TextEditingController _situacaoController;
  late TextEditingController _observacoesController;

  @override
  void initState() {
    super.initState();
    _descricaoController = TextEditingController(text: widget.patrimonio.descricao);
    _salaController = TextEditingController(text: widget.patrimonio.sala);
    _responsavelController = TextEditingController(text: widget.patrimonio.responsavel);
    _situacaoController = TextEditingController(text: widget.patrimonio.situacao);
    _observacoesController = TextEditingController(text: widget.patrimonio.observacoes);
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _salaController.dispose();
    _responsavelController.dispose();
    _situacaoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final updatedPatrimonio = widget.patrimonio.copyWith(
      descricao: _descricaoController.text,
      sala: _salaController.text,
      responsavel: _responsavelController.text,
      situacao: _situacaoController.text,
      observacoes: _observacoesController.text,
      isModified: true,
      // Here we could also track specific modified fields if needed
    );
    widget.onSave(updatedPatrimonio);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSalaDiferente = widget.selectedSala != null && 
                           widget.selectedSala!.isNotEmpty &&
                           _salaController.text != widget.selectedSala;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar for bottom sheet look
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patrimônio ${widget.patrimonio.numeroPatrimonio}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Verifique e atualize os dados',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Divider(height: 32),

          // Form Fields
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTextField(
                    controller: _descricaoController,
                    label: 'Descrição',
                    icon: Icons.description,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _salaController,
                    label: 'Sala',
                    icon: Icons.room,
                    isHighlighted: isSalaDiferente,
                    highlightMessage: 'Diferente da sala selecionada (${widget.selectedSala})',
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _responsavelController,
                          label: 'Responsável',
                          icon: Icons.person,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _situacaoController,
                          label: 'Situação',
                          icon: Icons.info_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _observacoesController,
                    label: 'Observações',
                    icon: Icons.note,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Salvar Alterações'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isHighlighted = false,
    String? highlightMessage,
    int maxLines = 1,
  }) {
    final color = isHighlighted ? Colors.orange : Colors.grey[700];
    final borderColor = isHighlighted ? Colors.orange : Colors.grey[300];
    final bgColor = isHighlighted ? Colors.orange.withOpacity(0.05) : Colors.grey[50];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor!),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: color),
              prefixIcon: Icon(icon, color: color),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (isHighlighted && highlightMessage != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  highlightMessage,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
