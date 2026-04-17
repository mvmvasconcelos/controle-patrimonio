import 'package:flutter/material.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../database/photo_database.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<PhotoRecord> photos;
  final int initialIndex;
  final bool readOnly;
  final Future<bool> Function(PhotoRecord photo)? onDelete;

  const PhotoViewerPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.readOnly = true,
    this.onDelete,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late List<PhotoRecord> _photos;
  late int _currentIndex;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _photos = List<PhotoRecord>.from(widget.photos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = _photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${_photos.length}'),
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: _photos.length,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: MemoryImage(_photos[index].imageBytes),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          if (!widget.readOnly)
            Positioned(
              right: 20,
              bottom: 24,
              child: FloatingActionButton(
                heroTag: 'delete-photo-${currentPhoto.id}',
                onPressed: _isDeleting ? null : _confirmDelete,
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                child: _isDeleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.delete),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final photo = _photos[_currentIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir foto?'),
        content: const Text('Esta foto será removida do item localmente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.onDelete == null) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final deleted = await widget.onDelete!(photo);
    if (!mounted) {
      return;
    }

    setState(() {
      _isDeleting = false;
    });

    if (!deleted) {
      return;
    }

    _photos.removeAt(_currentIndex);
    if (_photos.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }

    final nextIndex = _currentIndex >= _photos.length ? _photos.length - 1 : _currentIndex;
    setState(() {
      _currentIndex = nextIndex;
    });
    _pageController.jumpToPage(nextIndex);
  }
}