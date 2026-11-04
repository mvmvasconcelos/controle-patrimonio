import 'package:flutter/material.dart';

import '../services/offline/sync_status.dart';
import '../services/web_inventory_repository.dart';

/// Indicador permanente de conexão, pendências e Sincronização.
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({
    super.key,
    required this.repository,
    this.onSessionExpired,
  });

  final WebInventoryRepository repository;
  final VoidCallback? onSessionExpired;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: repository.syncStatusChanges,
      initialData: repository.syncStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? repository.syncStatus;
        final scheme = Theme.of(context).colorScheme;
        final color =
            status.online ? scheme.primaryContainer : scheme.errorContainer;
        return Material(
          color: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Icon(status.online ? Icons.cloud_done : Icons.cloud_off,
                    size: 18),
                Text(status.online ? 'Online' : 'Offline'),
                if (status.syncing) const Text('Sincronizando…'),
                if (status.pending > 0)
                  Text(
                      '${status.pending} ${status.pending == 1 ? 'pendência' : 'pendências'}'),
                if (status.failed > 0) Text('${status.failed} com erro'),
                if (status.conflicts > 0)
                  Text(
                      '${status.conflicts} edições substituídas por versões mais recentes'),
                if (status.sessionExpired) ...[
                  const Text('Sessão expirada'),
                  TextButton(
                    onPressed: onSessionExpired,
                    child: const Text('Entrar novamente'),
                  ),
                ],
                IconButton(
                  tooltip: 'Sincronizar agora',
                  visualDensity: VisualDensity.compact,
                  onPressed: status.syncing ? null : repository.synchronize,
                  icon: const Icon(Icons.sync, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
