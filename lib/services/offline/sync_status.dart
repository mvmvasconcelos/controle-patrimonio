class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.pending = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.sessionExpired = false,
    this.lastSyncAt,
    this.lastError,
  });

  /// Há rede e o servidor respondeu na última tentativa.
  final bool online;
  final bool syncing;

  /// Pendências na fila, incluindo as [failed].
  final int pending;

  /// Pendências rejeitadas pelo servidor; permanecem na fila, sinalizadas.
  final int failed;

  /// Edições locais descartadas na última sincronização por existir outra
  /// mais recente no servidor (last-write-wins).
  final int conflicts;
  final bool sessionExpired;
  final DateTime? lastSyncAt;
  final String? lastError;

  SyncStatus copyWith({
    bool? online,
    bool? syncing,
    int? pending,
    int? failed,
    int? conflicts,
    bool? sessionExpired,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        conflicts: conflicts ?? this.conflicts,
        sessionExpired: sessionExpired ?? this.sessionExpired,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}
