/// Tela Sobre do aplicativo.
/// 
/// Mostra informações sobre o aplicativo e gerencia o processo de atualização.
/// Permite também configurar o servidor de atualizações.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_info.dart';
import '../providers/update_provider.dart';
import '../services/update_service.dart';
import 'dart:io';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _showSettings = false;
  
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadServerSettings();
    // Registrar para observar mudanças no ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);
    // Verificar status da atualização quando a tela é aberta
    Future.microtask(() {
      final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
      updateProvider.checkIfUpdated();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    // Remover observador ao destruir o widget
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando o app é retomado do background
    if (state == AppLifecycleState.resumed) {
      // Verificar se a atualização foi concluída
      final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
      updateProvider.checkIfUpdated();
    }
  }
  
  Future<void> _loadAppInfo() async {
    await AppInfo.initialize();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadServerSettings() async {
    final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
    _ipController.text = updateProvider.serverIp;
    _portController.text = updateProvider.serverPort.toString();
  }
  
  // Alterna a visibilidade das configurações do servidor
  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      if (!_showSettings) {
        // Se esconder as configurações, carregar os valores atuais
        _loadServerSettings();
      }
    });
  }
  
  // Salva as configurações do servidor
  Future<void> _saveServerSettings() async {
    final String ip = _ipController.text.trim();
    final int port = int.tryParse(_portController.text.trim()) ?? 8090;
    
    if (ip.isNotEmpty) {
      final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
      await updateProvider.saveServerSettings(ip, port);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações de servidor salvas'),
            duration: Duration(seconds: 2),
          ),
        );
        
        setState(() {
          _showSettings = false;
        });
      }
    }
  }
  
  // Verifica por atualizações
  Future<void> _checkForUpdates() async {
    final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
    
    final result = await updateProvider.checkForUpdates();
    
    // Se houver uma atualização, mostrar o botão para atualizar
    if (result.status == UpdateStatus.updateAvailable) {
      _showUpdateDialog(result);
    } else if (result.status == UpdateStatus.serverUnavailable) {
      // Se o servidor estiver indisponível, possibilitar alterar configurações
      _showServerConfigDialog(result.error);
    }
  }
  
  // Diálogo para confirmar atualização
  void _showUpdateDialog(UpdateCheckResult result) {
    // Extrair a versão e build number do formato completo (1.0.4+5)
    String displayVersion = result.latestVersion ?? 'mais recente';
    String buildNumber = '';
    
    if (result.latestVersion != null && result.latestVersion!.contains('+')) {
      final parts = result.latestVersion!.split('+');
      displayVersion = parts[0];
      buildNumber = parts[1];
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova versão disponível'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja baixar e instalar a versão $displayVersion (build $buildNumber)?'),
            const SizedBox(height: 8),
            Text(
              'Sua versão atual: ${AppInfo.getFullVersion()}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('CANCELAR'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('ATUALIZAR'),
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstallUpdate();
            },
          ),
        ],
      ),
    );
  }
  
  // Baixa e instala a atualização
  Future<void> _downloadAndInstallUpdate() async {
    // Primeiro exibe o diálogo de instruções para garantir que ele apareça antes da instalação
    // O usuário precisa confirmar que entendeu antes de prosseguir com o download
    _showInstallationInstructionsDialog(downloadAfterConfirm: true);
  }

  // Função executada após confirmar o diálogo de instruções
  Future<void> _proceedWithDownload() async {
    final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
    
    final result = await updateProvider.downloadAndInstallUpdate();
    
    // Se houver erro ou a instalação não iniciar com sucesso, mostrar mensagem
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${result.message}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } else {
      // Se a instalação foi iniciada com sucesso, encerrar o app
      Future.delayed(const Duration(seconds: 2), () {
        exit(0);
      });
    }
  }
  
  // Diálogo para configuração do servidor quando indisponível
  void _showServerConfigDialog(String? errorDetail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Servidor indisponível'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provavelmente o servidor está offline.'),
            const SizedBox(height: 8),
            if (errorDetail != null)
              Text(
                'Erro: $errorDetail',
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
              ),
            const SizedBox(height: 16),
            const Text('Entre em contato com o responsável pelo servidor de atualizações.'),
            const Text('Ou configure o IP e porta do servidor manualmente.'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('CANCELAR'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('CONFIGURAR'),
            onPressed: () {
              Navigator.of(context).pop();
              _toggleSettings();
            },
          ),
        ],
      ),
    );
  }
  
  // Diálogo com instruções para a instalação
  void _showInstallationInstructionsDialog({bool shouldExitApp = false, bool downloadAfterConfirm = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Instruções de instalação'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Após o download, uma janela do sistema para instalação do aplicativo será exibida.'),
            SizedBox(height: 12),
            Text('Siga estas etapas:'),
            SizedBox(height: 8),
            Text('1. Toque em "Instalar" quando solicitado'),
            Text('2. Se solicitado, conceda permissão para instalar o aplicativo'),
            Text('3. Aguarde a conclusão da instalação'),
            Text('4. Toque em "Abrir" para iniciar o aplicativo atualizado'),
            SizedBox(height: 12),
            Text('Nota: O aplicativo será fechado automaticamente após o início da instalação.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              if (downloadAfterConfirm) {
                // Iniciar o download após fechar o diálogo
                _proceedWithDownload();
              } else if (shouldExitApp) {
                // Fechar o aplicativo se necessário
                exit(0);
              }
            },
            child: const Text('ENTENDI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final updateProvider = Provider.of<UpdateProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.close : Icons.settings),
            onPressed: _toggleSettings,
            tooltip: _showSettings ? 'Fechar configurações' : 'Configurações do servidor',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                // Conteúdo principal (informações sobre o app)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppInfo.appName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppInfo.getFullVersion(), // Usando o método que já inclui o número de build
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppInfo.releaseDate,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Desenvolvido em IFSul Câmpus Venâncio Aires',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
                
                // Configurações do servidor (visível apenas quando _showSettings é true)
                if (_showSettings)
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configurações do servidor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Endereço IP do servidor:'),
                          TextField(
                            controller: _ipController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              hintText: 'Ex: 192.168.0.100',
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Porta:'),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Ex: 8090',
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: _saveServerSettings,
                              child: const Text('SALVAR'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Observação: O servidor precisa estar acessível a partir do dispositivo móvel. '
                            'Certifique-se de que ambos estejam na mesma rede.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Botão de verificar atualizações
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        // Mensagem de status da atualização
                        if (updateProvider.showUpdateMessage)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  updateProvider.updateMessage,
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                                if (updateProvider.isDownloading)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: LinearProgressIndicator(
                                      value: updateProvider.downloadProgress,
                                      backgroundColor: colorScheme.onSurfaceVariant.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                        // Botão de verificar atualizações
                        ElevatedButton.icon(
                          onPressed: (updateProvider.isCheckingForUpdates || 
                                      updateProvider.isDownloading || 
                                      _showSettings)
                              ? null
                              : _checkForUpdates,
                          icon: updateProvider.isCheckingForUpdates
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(2.0),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.system_update),
                          label: Text(updateProvider.isCheckingForUpdates
                              ? 'Verificando...'
                              : 'Verificar atualizações'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
