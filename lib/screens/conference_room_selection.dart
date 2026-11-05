import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';

Future<String?> selectConferenceRoom(
  BuildContext context,
  WebInventoryRepository repository,
) async {
  List<String> rooms;
  try {
    rooms = (await repository.fetchFilters()).rooms;
  } catch (_) {
    rooms = const [];
  }
  if (!context.mounted) return null;

  String? selectedRoom;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Selecionar Sala'),
        content: rooms.isEmpty
            ? const Text('Não há Salas cadastradas no Inventário.')
            : DropdownButtonFormField<String>(
                key: const ValueKey('conference-room-selector'),
                value: selectedRoom,
                decoration: const InputDecoration(
                  labelText: 'Sala',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final room in rooms)
                    DropdownMenuItem(value: room, child: Text(room)),
                ],
                onChanged: (room) => setDialogState(() => selectedRoom = room),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: selectedRoom == null
                ? null
                : () => Navigator.of(context).pop(selectedRoom),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmRoomCorrection(
  BuildContext context, {
  required String number,
  required String expectedRoom,
  required String actualRoom,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sala divergente'),
          content: Text(
            'O Patrimônio $number está cadastrado na $actualRoom, mas '
            'você está conferindo a $expectedRoom.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Corrigir Sala'),
            ),
          ],
        ),
      ) ??
      false;
}
