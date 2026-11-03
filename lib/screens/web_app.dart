import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';

class WebApp extends StatefulWidget {
  const WebApp({super.key, this.repository});

  final WebInventoryRepository? repository;

  @override
  State<WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<WebApp> {
  late final WebInventoryRepository _repository =
      widget.repository ?? WebInventoryRepository();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  AdminSession? _session;
  List<InventoryEntry> _inventory = const [];
  String? _error;
  bool _isLoading = true;
  bool _ownsRepository = false;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _restoreSession();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    if (_ownsRepository) {
      _repository.close();
    }
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _repository.restoreSession();
      if (session != null) {
        _session = session;
        _inventory = await _repository.loadInventory();
      }
    } catch (error) {
      _error = _message(error);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Informe o usuário e a senha.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _session = await _repository.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      _inventory = await _repository.loadInventory();
    } catch (error) {
      _error = _message(error);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _repository.logout();
      _session = null;
      _inventory = const [];
      _passwordController.clear();
    } catch (error) {
      _error = _message(error);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _message(Object error) => error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session == null) {
      return _buildLogin();
    }
    return _buildInventory();
  }

  Widget _buildLogin() {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Controle Patrimonial',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acesso do Administrador',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Usuário',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _login,
                      child: const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventory() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(_session!.username)),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_inventory.length} patrimônios'),
            ),
          ),
          Expanded(
            child: _inventory.isEmpty
                ? const Center(child: Text('Nenhum patrimônio encontrado.'))
                : ListView.separated(
                    itemCount: _inventory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = _inventory[index];
                      return ListTile(
                        title: Text(entry.description),
                        subtitle: Text(
                          '${entry.number} • ${entry.room} • ${entry.responsible}',
                        ),
                        trailing: Text(entry.status),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
