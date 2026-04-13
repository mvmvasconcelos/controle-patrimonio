import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/patrimonio_provider.dart';
import 'individual_scan_page.dart';
import 'batch_scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Carregar dados locais ao iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatrimonioProvider>().loadLocalData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle Patrimônio'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => Navigator.pushNamed(context, '/data'),
            tooltip: 'Importar / Exportar planilha',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncData,
            tooltip: 'Sincronizar dados',
          ),
          Consumer<PatrimonioProvider>(
            builder: (context, provider, _) {
              final count = provider.patrimonios.where((p) => p.isModified).length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_chart),
                    onPressed: () => Navigator.pushNamed(context, '/report'),
                    tooltip: 'Relatório de alterações',
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showAbout,
            tooltip: 'Sobre',
          ),
        ],
      ),
      body: Consumer<PatrimonioProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sincronizando dados...'),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Erro: ${provider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.syncWithBackend();
                    },
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status da sincronização
                if (provider.lastSync != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Última sincronização:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatDateTime(provider.lastSync!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${provider.patrimonios.length} itens carregados',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Botões principais
                ElevatedButton.icon(
                  onPressed: () => _startIndividualScan(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 32),
                  label: const Text(
                    'Escaneamento Individual',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () => _startBatchScan(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 32),
                  label: const Text(
                    'Escaneamento em Lotes',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Estatísticas rápidas
                if (provider.hasData) ...[
                  const Text(
                    'Estatísticas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        'Total',
                        provider.patrimonios.length.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Modificados',
                        provider.getStatistics()['modified'].toString(),
                        Icons.edit,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncData() async {
    final provider = context.read<PatrimonioProvider>();
    await provider.syncWithBackend();
  }

  void _showAbout() {
    Navigator.pushNamed(context, '/about');
  }

  Future<void> _startIndividualScan(BuildContext context) async {
    final navigator = Navigator.of(context);
    final sala = await _showSalaSelectionDialog(context);
    if (!mounted) return;

    // Se o diálogo retornou null -> usuário cancelou (fechou com X)
    if (sala == null) return;

    // sala == ''  => usuário confirmou sem selecionar sala -> passamos null
    final selectedSala = sala.isEmpty ? null : sala;

    navigator.push(
      MaterialPageRoute(
        builder: (context) => IndividualScanPage(selectedSala: selectedSala),
      ),
    );
  }

  Future<void> _startBatchScan(BuildContext context) async {
    final navigator = Navigator.of(context);
    final sala = await _showSalaSelectionDialog(context);
    if (!mounted) return;

    if (sala == null) return; // usuário cancelou com X

    final selectedSala = sala.isEmpty ? null : sala;

    navigator.push(
      MaterialPageRoute(
        builder: (context) => BatchScanPage(selectedSala: selectedSala),
      ),
    );
  }

  Future<String?> _showSalaSelectionDialog(BuildContext context) async {
    final provider = context.read<PatrimonioProvider>();
    final salas = provider.patrimonios
        .map((p) => p.sala)
        .toSet()
        .toList()
      ..sort();

    // Use a local state inside the dialog so the Confirm button can be
    // habilitado apenas quando o usuário escolher uma sala. O botão "Não"
    // permite prosseguir com o scanner sem informar a sala (retorna
    // 'Não informada').
    // O diálogo permite confirmar sem selecionar sala (seleção opcional).
    // O 'X' no canto fecha o diálogo e cancela a ação (retorna null).
    // Ao confirmar, retornamos a sala selecionada ou a string vazia ('')
    // para indicar que o usuário confirmou sem escolher sala.
    return showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        String? selectedLocal;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('Selecionar Sala')),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(null),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Deseja informar qual é a sala? (opcional)',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.maxFinite,
                    child: DropdownButtonFormField<String>(
                      value: selectedLocal,
                      decoration: const InputDecoration(
                        labelText: 'Sala',
                        border: OutlineInputBorder(),
                      ),
                      items: salas.map((sala) {
                        return DropdownMenuItem<String>(
                          value: sala,
                          child: Text(sala),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLocal = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // "Não" -> confirmar sem escolher sala
                    Navigator.of(context).pop('');
                  },
                  child: const Text('Não'),
                ),
                ElevatedButton(
                  onPressed: selectedLocal == null
                      ? null
                      : () {
                          Navigator.of(context).pop(selectedLocal);
                        },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
           '${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}