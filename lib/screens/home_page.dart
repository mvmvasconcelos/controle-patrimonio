import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/photo_database.dart';
import '../providers/patrimonio_provider.dart';
import '../services/photo_sync_service.dart';
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
      ),
      drawer: _buildDrawer(context),
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
            return Scaffold(
              appBar: AppBar(
                title: const Text('Controle Patrimônio'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    provider.clearError();
                  },
                ),
              ),
              drawer: _buildDrawer(context),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text(
                      'Falha na sincronização',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Não foi possível conectar ao servidor. Verifique sua conexão de internet e tente novamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            provider.clearError();
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Descartar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            provider.clearError();
                            provider.syncWithBackend();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  ],
                ),
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

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/inventory'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text(
                    'Ver Inventário',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Consumer<PatrimonioProvider>(
        builder: (context, provider, _) {
          final modifiedCount =
              provider.patrimonios.where((p) => p.isModified).length;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.inventory_2, color: Colors.white, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Controle Patrimônio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'IFSUL',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Inventário'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/inventory');
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Importar / Exportar'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/data');
                },
              ),
              ListTile(
                leading: Badge(
                  isLabelVisible: modifiedCount > 0,
                  label: Text('$modifiedCount'),
                  child: const Icon(Icons.table_chart),
                ),
                title: const Text('Relatório de alterações'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/report');
                },
              ),
              const Divider(),
              ListTile(
                leading: FutureBuilder<int>(
                  future: PhotoDatabase.getPendingSyncCount(),
                  builder: (context, snapshot) {
                    final pending = snapshot.data ?? 0;
                    if (pending <= 0) {
                      return const Icon(Icons.sync);
                    }
                    return Badge(
                      label: Text('$pending'),
                      child: const Icon(Icons.sync),
                    );
                  },
                ),
                title: const Text('Sincronizar com servidor'),
                onTap: () {
                  Navigator.pop(context);
                  _syncData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Gerenciar Dados e Cache'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/data-cache');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Sobre / Atualizações'),
                onTap: () {
                  Navigator.pop(context);
                  _showAbout();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _syncData() async {
    final provider = context.read<PatrimonioProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await provider.sendUpdatesToBackend();
    if (!mounted) {
      return;
    }

    await provider.syncWithBackend();
    if (!mounted) {
      return;
    }

    final photoSynced = await PhotoSyncService.syncAll(context);

    if (!mounted) {
      return;
    }

    final error = provider.error;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          photoSynced
              ? 'Sincronização concluída com sucesso.'
              : 'Dados sincronizados. Sem alterações de foto pendentes.',
        ),
        backgroundColor: Colors.green,
      ),
    );
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
        .where((sala) => sala.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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