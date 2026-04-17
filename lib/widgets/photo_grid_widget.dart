import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../database/photo_database.dart';
import '../screens/photo_viewer_page.dart';
import '../services/photo_service.dart';
import '../services/photo_sync_service.dart';

class PhotoGridWidget extends StatefulWidget {
  final String numeroPatrimonio;
  final bool readOnly;

  const PhotoGridWidget({
    super.key,
    required this.numeroPatrimonio,
    this.readOnly = false,
  });

  @override
  State<PhotoGridWidget> createState() => _PhotoGridWidgetState();
}

class _PhotoGridWidgetState extends State<PhotoGridWidget> {
  List<PhotoRecord> _photos = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _recoverLostPhoto();
  }

  @override
  void didUpdateWidget(covariant PhotoGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numeroPatrimonio != widget.numeroPatrimonio) {
      _loadPhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final itemCount = widget.readOnly
        ? _photos.length
        : (_photos.length < PhotoDatabase.maxPhotos ? _photos.length + 1 : _photos.length);

    if (itemCount == 0 && widget.readOnly) {
      return const Text(
        'Nenhuma foto cadastrada para este item.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos do item',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (_pendingCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            '$_pendingCount foto(s) pendente(s) de sincronização',
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ],
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (!widget.readOnly && index == _photos.length) {
              return _buildAddTile();
            }

            final photo = _photos[index];
            return _buildPhotoTile(photo, index);
          },
        ),
      ],
    );
  }

  Widget _buildPhotoTile(PhotoRecord photo, int index) {
    return InkWell(
      onTap: () => _openViewer(index),
      borderRadius: BorderRadius.circular(12),
      child: Hero(
        tag: 'photo-${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(
              image: MemoryImage(photo.imageBytes),
              fit: BoxFit.cover,
            ),
          ),
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.all(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTile() {
    return InkWell(
      onTap: _isSaving ? null : _showAddOptions,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid),
          color: Colors.blue.shade50,
        ),
        child: Center(
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo, color: Colors.blue, size: 30),
                    SizedBox(height: 8),
                    Text(
                      'Adicionar',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    final photos = await PhotoDatabase.getPhotos(widget.numeroPatrimonio);
    if (!mounted) {
      return;
    }

    setState(() {
      _photos = photos;
      _isLoading = false;
    });

    final pending = await PhotoDatabase.getPendingSyncCountForItem(widget.numeroPatrimonio);
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingCount = pending;
    });
  }

  Future<void> _recoverLostPhoto() async {
    if (widget.readOnly) {
      return;
    }

    final recovered = await PhotoService.recoverLostData();
    if (recovered == null || !mounted) {
      return;
    }

    await _savePhotoBytes(recovered);
  }

  Future<void> _showAddOptions() async {
    final action = await showModalBottomSheet<_PhotoInputAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Câmera'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoInputAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoInputAction.gallery),
            ),
          ],
        ),
      ),
    );

    if (action == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = action == _PhotoInputAction.camera
          ? await PhotoService.captureFromCamera()
          : await PhotoService.pickFromGallery();

      if (bytes == null) {
        if (mounted) {
          await PhotoService.handlePermanentPermissionDenial(context);
        }
        return;
      }

      await _savePhotoBytes(bytes);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _savePhotoBytes(Uint8List bytes) async {
    await PhotoDatabase.addPhoto(widget.numeroPatrimonio, bytes);
    await _loadPhotos();
    if (!mounted) {
      return;
    }

    await PhotoSyncService.syncAll(context);
    if (!mounted || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto salva localmente com sucesso.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openViewer(int initialIndex) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          photos: _photos,
          initialIndex: initialIndex,
          readOnly: widget.readOnly,
          onDelete: widget.readOnly ? null : _deletePhoto,
        ),
      ),
    );

    await _loadPhotos();
  }

  Future<bool> _deletePhoto(PhotoRecord photo) async {
    if (photo.serverPhotoId != null) {
      await PhotoDatabase.enqueueRemoteDelete(photo);
    }
    await PhotoDatabase.deletePhoto(photo.id);
    if (mounted) {
      await PhotoSyncService.syncAll(context);
    }

    if (!mounted || !context.mounted) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto removida localmente.')),
    );
    return true;
  }
}

enum _PhotoInputAction { camera, gallery }