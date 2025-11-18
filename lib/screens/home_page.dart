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
  String? _selectedSala;

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
            icon: const Icon(Icons.sync),
            onPressed: _syncData,
            tooltip: 'Sincronizar dados',
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
    final sala = await _showSalaSelectionDialog(context);
    if (sala != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IndividualScanPage(selectedSala: sala),
        ),
      );
    }
  }

  Future<void> _startBatchScan(BuildContext context) async {
    final sala = await _showSalaSelectionDialog(context);
    if (sala != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BatchScanPage(selectedSala: sala),
        ),
      );
    }
  }

  Future<String?> _showSalaSelectionDialog(BuildContext context) async {
    final provider = context.read<PatrimonioProvider>();
    final salas = provider.patrimonios
        .map((p) => p.sala)
        .toSet()
        .toList()
      ..sort();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecionar Sala'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Deseja informar qual é a sala?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: DropdownButtonFormField<String>(
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
                    _selectedSala = value;
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_selectedSala);
              },
              child: const Text('Confirmar'),
            ),
          ],
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