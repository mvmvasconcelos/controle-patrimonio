import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/patrimonio_provider.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  bool _isProcessing = false;

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showResetModificationsDialog(int modifiedCount) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Resetar modificações?'),
        content: Text(
          'Isso descartará todas as alterações feitas em $modifiedCount item(ns) e os restaurará para o estado anterior.\n\n'
          'Esta ação pode ser desfeita sincronizando com o servidor novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              try {
                final provider = context.read<PatrimonioProvider>();
                await provider.resetModifications();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Modificações resetadas com sucesso'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showError('Erro ao resetar modificações: $e');
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text(
              'Resetar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Limpar tudo?'),
        content: const Text(
          'Isso removerá TODOS os dados armazenados localmente, incluindo:\n\n'
          '- Todos os itens importados\n'
          '- Todas as fotos armazenadas localmente\n'
          '- Todas as modificações\n'
          '- Histórico de sincronização\n\n'
          'Fotos ainda não sincronizadas serão perdidas definitivamente. Fotos já enviadas ao servidor poderão ser restauradas depois.\n\n'
          'Esta ação NÃO pode ser desfeita. Para recuperar os dados, você precisará importar a planilha novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              try {
                final provider = context.read<PatrimonioProvider>();
                await provider.clearAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Todos os dados foram limpos'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showError('Erro ao limpar dados: $e');
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text(
              'Limpar tudo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Dados e Cache'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<PatrimonioProvider>(
        builder: (context, provider, _) {
          final totalItems = provider.patrimonios.length;
          final modifiedCount =
              provider.patrimonios.where((p) => p.isModified).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatTile(
                        label: 'Total importado',
                        value: '$totalItems',
                        icon: Icons.inventory_2,
                      ),
                      _StatTile(
                        label: 'Modificados',
                        value: '$modifiedCount',
                        icon: Icons.edit,
                        valueColor: modifiedCount > 0 ? Colors.orange : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ações de risco',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Estas operações removem alterações locais e devem ser usadas com cuidado.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing || modifiedCount == 0
                    ? null
                    : () => _showResetModificationsDialog(modifiedCount),
                icon: const Icon(Icons.restart_alt),
                label: Text(
                  modifiedCount > 0
                      ? 'Resetar modificações ($modifiedCount)'
                      : 'Nenhuma modificação para resetar',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showClearAllDialog,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.delete_sweep),
                label: Text(_isProcessing ? 'Processando...' : 'Limpar tudo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: valueColor ?? Colors.blueGrey),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
