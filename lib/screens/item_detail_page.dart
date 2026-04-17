import 'package:flutter/material.dart';

import '../database/photo_database.dart';
import '../models/patrimonio.dart';
import '../services/photo_sync_service.dart';
import '../widgets/photo_grid_widget.dart';

class ItemDetailPage extends StatefulWidget {
  final Patrimonio patrimonio;

  const ItemDetailPage({
    super.key,
    required this.patrimonio,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  bool _isRestoring = false;
  int _gridVersion = 0;

  @override
  void initState() {
    super.initState();
    _tryRestorePhotosOnDemand();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patrimonio;

    return Scaffold(
      appBar: AppBar(
        title: Text('Item ${p.numeroPatrimonio}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isRestoring)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            _InfoCard(
              icon: Icons.inventory_2,
              title: 'Número Patrimonial',
              value: p.numeroPatrimonio,
            ),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.description,
              title: 'Descrição',
              value: p.descricao,
            ),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.room,
              title: 'Sala',
              value: p.sala,
            ),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.person,
              title: 'Responsável',
              value: p.responsavel,
            ),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.info_outline,
              title: 'Situação',
              value: p.situacao,
            ),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.note,
              title: 'Observações',
              value: (p.observacoes ?? '').trim().isEmpty
                  ? 'Sem observações'
                  : p.observacoes!,
            ),
            const SizedBox(height: 16),
            PhotoGridWidget(
              key: ValueKey('detail-photo-grid-$_gridVersion-${p.numeroPatrimonio}'),
              numeroPatrimonio: p.numeroPatrimonio,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Para editar dados ou adicionar/remover fotos, use o escaneamento individual.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryRestorePhotosOnDemand() async {
    final numero = widget.patrimonio.numeroPatrimonio;
    final hasLocal = await PhotoDatabase.hasPhotos(numero);
    if (hasLocal || !mounted) {
      return;
    }

    setState(() {
      _isRestoring = true;
    });

    try {
      await PhotoSyncService.downloadPhotos([numero]);
      final hasAfter = await PhotoDatabase.hasPhotos(numero);
      if (!mounted) {
        return;
      }

      if (hasAfter) {
        setState(() {
          _gridVersion += 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotos restauradas do servidor para este item.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível restaurar fotos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(value),
      ),
    );
  }
}