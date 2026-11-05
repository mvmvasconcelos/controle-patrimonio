import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'conference_room_selection.dart';
import '../services/web_inventory_repository.dart';
import '../services/web_photo_picker.dart';
import '../widgets/barcode_scanner_screen.dart';

typedef BarcodeScanner = Future<String?> Function(BuildContext context);

Future<String?> scanWithCamera(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

String errorMessage(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

class WebPatrimonyDetailPage extends StatefulWidget {
  const WebPatrimonyDetailPage({
    super.key,
    required this.repository,
    required this.entry,
    this.photoPicker,
  });

  final WebInventoryRepository repository;
  final InventoryEntry entry;
  final WebPhotoPicker? photoPicker;

  @override
  State<WebPatrimonyDetailPage> createState() => _WebPatrimonyDetailPageState();
}

class _WebPatrimonyDetailPageState extends State<WebPatrimonyDetailPage> {
  late InventoryEntry _entry = widget.entry;
  late final _description = TextEditingController(text: _entry.description);
  late final _room = TextEditingController(text: _entry.room);
  late final _responsible = TextEditingController(text: _entry.responsible);
  late final _status = TextEditingController(text: _entry.status);
  late final _notes = TextEditingController(text: _entry.notes ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  String? _info;
  late final WebPhotoPicker _photoPicker =
      widget.photoPicker ?? BrowserPhotoPicker();
  List<PatrimonyPhoto> _photos = const [];
  final _photoBytes = <int, Future<Uint8List>>{};
  bool _photosBusy = false;
  String? _photoError;
  String? _photoInfo;

  @override
  void initState() {
    super.initState();
    _runPhotos(_loadPhotos);
  }

  @override
  void dispose() {
    for (final c in [_description, _room, _responsible, _status, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (error) {
      _error = errorMessage(error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _runPhotos(Future<void> Function() action) async {
    setState(() {
      _photosBusy = true;
      _photoError = null;
      _photoInfo = null;
    });
    try {
      await action();
    } catch (error) {
      _photoError = errorMessage(error);
    }
    if (mounted) setState(() => _photosBusy = false);
  }

  Future<void> _loadPhotos() async {
    _photos = await widget.repository.fetchPhotos(_entry.number);
  }

  Future<void> _addPhoto(PhotoSource source) => _runPhotos(() async {
        final bytes = await _photoPicker.pick(source);
        if (bytes == null) return;
        await widget.repository.uploadPhoto(_entry.number, bytes);
        await _loadPhotos();
        _photoInfo = 'Foto adicionada.';
      });

  Future<void> _removePhoto(PatrimonyPhoto photo) => _runPhotos(() async {
        await widget.repository.deletePhoto(_entry.number, photo.id);
        _photoBytes.remove(photo.id);
        await _loadPhotos();
        _photoInfo = 'Foto removida.';
      });

  Future<void> _openPhoto(PatrimonyPhoto photo) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child:
                    _PhotoImage(bytes: _bytesFor(photo), fit: BoxFit.contain),
              ),
            ),
            OverflowBar(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Fechar'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (remove != true || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _removePhoto(photo);
  }

  Future<Uint8List> _bytesFor(PatrimonyPhoto photo) => _photoBytes.putIfAbsent(
      photo.id,
      () => widget.repository.fetchPhotoBytes(_entry.number, photo.id));

  Widget _photosSection(BuildContext context) {
    final atLimit = _photos.length >= maxPhotosPerPatrimony;
    final canAdd = !_photosBusy && !atLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos (${_photos.length}/$maxPhotosPerPatrimony)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_photos.isEmpty && !_photosBusy && _photoError == null)
          const Text('Nenhuma foto anexada.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in _photos)
              InkWell(
                key: ValueKey('photo-${photo.id}'),
                onTap: _photosBusy ? null : () => _openPhoto(photo),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: _PhotoImage(bytes: _bytesFor(photo)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: canAdd ? () => _addPhoto(PhotoSource.camera) : null,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tirar foto'),
            ),
            OutlinedButton.icon(
              onPressed: canAdd ? () => _addPhoto(PhotoSource.file) : null,
              icon: const Icon(Icons.attach_file),
              label: const Text('Escolher arquivo'),
            ),
          ],
        ),
        if (atLimit) const Text('Limite de 3 fotos atingido.'),
        if (_photosBusy) const LinearProgressIndicator(),
        if (_photoError != null)
          Text(_photoError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_photoInfo != null) Text(_photoInfo!),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final changes = <String, String?>{
      if (_description.text.trim() != _entry.description)
        'descricao': _description.text.trim(),
      if (_room.text.trim() != _entry.room) 'sala': _room.text.trim(),
      if (_responsible.text.trim() != _entry.responsible)
        'responsavel': _responsible.text.trim(),
      if (_status.text.trim() != _entry.status) 'situacao': _status.text.trim(),
      if (_notes.text.trim() != (_entry.notes ?? '').trim())
        'observacoes': _notes.text.trim(),
    };
    if (changes.isEmpty) {
      setState(() => _info = 'Nenhuma alteração para salvar.');
      return;
    }
    await _run(() async {
      _entry = await widget.repository.updateEntry(_entry.number, changes);
      _info = 'Patrimônio atualizado.';
    });
  }

  Future<void> _markChecked() => _run(() async {
        await widget.repository.markChecked(_entry.number);
        _entry = await widget.repository.fetchEntry(_entry.number) ?? _entry;
        _info = 'Patrimônio conferido.';
      });

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

  Widget _field(String label, TextEditingController controller,
      {bool required = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required ? _required : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Patrimônio ${_entry.number}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Icon(
                    _entry.checked
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _entry.checked ? Colors.green : null,
                  ),
                  const SizedBox(width: 8),
                  Text(_entry.checked ? 'Conferido' : 'Não conferido'),
                  const Spacer(),
                  if (!_entry.checked)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _markChecked,
                      icon: const Icon(Icons.fact_check),
                      label: const Text('Marcar como conferido'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field('Descrição', _description),
                    _field('Sala', _room),
                    _field('Responsável', _responsible),
                    _field('Situação', _status),
                    _field('Observações', _notes, required: false, maxLines: 3),
                  ],
                ),
              ),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_info != null) Text(_info!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Salvar'),
              ),
              const Divider(height: 32),
              _photosSection(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.bytes, this.fit = BoxFit.cover});

  final Future<Uint8List> bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.broken_image));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.memory(data, fit: fit);
      },
    );
  }
}

class WebNewPatrimonyPage extends StatefulWidget {
  const WebNewPatrimonyPage({
    super.key,
    required this.repository,
    this.initialNumber = '',
    this.markChecked = false,
  });

  final WebInventoryRepository repository;
  final String initialNumber;
  final bool markChecked;

  @override
  State<WebNewPatrimonyPage> createState() => _WebNewPatrimonyPageState();
}

class _WebNewPatrimonyPageState extends State<WebNewPatrimonyPage> {
  late final _number = TextEditingController(text: widget.initialNumber);
  final _description = TextEditingController();
  final _room = TextEditingController();
  final _responsible = TextEditingController();
  final _status = TextEditingController(text: 'Ativo');
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _number,
      _description,
      _room,
      _responsible,
      _status,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entry = await widget.repository.createEntry(NewInventoryEntry(
        number: _number.text.trim(),
        description: _description.text.trim(),
        room: _room.text.trim(),
        responsible: _responsible.text.trim(),
        status: _status.text.trim(),
        checked: widget.markChecked,
        notes: _notes.text.trim(),
      ));
      if (mounted) Navigator.of(context).pop(entry);
      return;
    } catch (error) {
      _error = errorMessage(error);
    }
    if (mounted) setState(() => _busy = false);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

  Widget _field(String label, TextEditingController controller,
      {bool required = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required ? _required : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo patrimônio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field('Número do patrimônio', _number),
                    _field('Descrição', _description),
                    _field('Sala', _room),
                    _field('Responsável', _responsible),
                    _field('Situação', _status),
                    _field('Observações', _notes, required: false, maxLines: 3),
                  ],
                ),
              ),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebConferenciaPage extends StatefulWidget {
  const WebConferenciaPage({
    super.key,
    required this.repository,
    this.scanBarcode,
  });

  final WebInventoryRepository repository;
  final BarcodeScanner? scanBarcode;

  @override
  State<WebConferenciaPage> createState() => _WebConferenciaPageState();
}

class _WebConferenciaPageState extends State<WebConferenciaPage> {
  final _number = TextEditingController();
  String? _selectedRoom;
  bool _roomDialogScheduled = false;
  bool _busy = false;
  String? _success;
  String? _error;
  String? _unknownNumber;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roomDialogScheduled) return;
    _roomDialogScheduled = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_selectRoom()));
  }

  Future<void> _selectRoom() async {
    final room = await selectConferenceRoom(context, widget.repository);
    if (mounted) setState(() => _selectedRoom = room);
  }

  // A câmera no navegador só funciona em contexto seguro (HTTPS ou localhost).
  bool get _cameraAvailable =>
      widget.scanBarcode != null ||
      !kIsWeb ||
      Uri.base.scheme == 'https' ||
      Uri.base.host == 'localhost' ||
      Uri.base.host == '127.0.0.1';

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _confirm(String raw) async {
    final number = raw.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Informe o número do patrimônio.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
      _unknownNumber = null;
    });
    try {
      await widget.repository.markChecked(number);
      InventoryEntry? entry;
      try {
        entry = await widget.repository.fetchEntry(number);
      } catch (_) {}
      if (!mounted) return;
      if (_selectedRoom != null && entry != null) {
        if (entry.room.trim() == _selectedRoom) {
          _success =
              'Patrimônio $number conferido. Sala correta: ${entry.room}.';
        } else {
          _success =
              'Patrimônio $number conferido. Sala divergente: cadastro em '
              '${entry.room.isEmpty ? 'sem Sala' : entry.room}.';
          final correctRoom = await confirmRoomCorrection(
            context,
            number: number,
            expectedRoom: _selectedRoom!,
            actualRoom: entry.room.isEmpty ? 'sem Sala' : entry.room,
          );
          if (correctRoom && mounted) {
            await Navigator.of(context).push<void>(MaterialPageRoute(
              builder: (_) => WebPatrimonyDetailPage(
                repository: widget.repository,
                entry: entry!,
              ),
            ));
            try {
              final updated = await widget.repository.fetchEntry(number);
              if (updated != null && updated.room.trim() == _selectedRoom) {
                _success =
                    'Patrimônio $number conferido. Sala corrigida para ${updated.room}.';
              }
            } catch (_) {}
          }
        }
      } else {
        _success = 'Patrimônio $number conferido.';
      }
      _number.clear();
    } on PatrimonyNotFoundException {
      _unknownNumber = number;
    } catch (error) {
      _error = errorMessage(error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _scan() async {
    final scan = widget.scanBarcode ?? scanWithCamera;
    String? value;
    try {
      value = await scan(context);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
      return;
    }
    if (value != null && value.trim().isNotEmpty && mounted) {
      _number.text = value.trim();
      await _confirm(value);
    }
  }

  Future<void> _registerUnknown() async {
    final number = _unknownNumber!;
    final created = await Navigator.of(context).push<InventoryEntry>(
      MaterialPageRoute(
        builder: (_) => WebNewPatrimonyPage(
          repository: widget.repository,
          initialNumber: number,
          markChecked: true,
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _unknownNumber = null;
      _success = 'Patrimônio ${created.number} cadastrado e conferido.';
      _number.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conferência')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Sala: ${_selectedRoom ?? 'Não informada'}'),
              const SizedBox(height: 12),
              TextField(
                controller: _number,
                autofocus: true,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Número do patrimônio',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _confirm,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _confirm(_number.text),
                icon: const Icon(Icons.search),
                label: const Text('Pesquisar manualmente'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy || !_cameraAvailable ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear'),
              ),
              if (!_cameraAvailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('A câmera exige HTTPS. Use a digitação manual.'),
                ),
              const SizedBox(height: 16),
              if (_success != null)
                Text(_success!, style: const TextStyle(color: Colors.green)),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_unknownNumber != null) ...[
                Text('Patrimônio $_unknownNumber não está no Inventário.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _registerUnknown,
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar patrimônio'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
