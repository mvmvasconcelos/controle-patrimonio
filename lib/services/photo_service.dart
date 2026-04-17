import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoService {
  static const int _maxDimension = 1280;
  static const int _jpegQuality = 85;
  static final ImagePicker _picker = ImagePicker();

  static Future<Uint8List?> captureFromCamera() async {
    final hasPermission = await requestPermissions(cameraOnly: true);
    if (!hasPermission) {
      return null;
    }

    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) {
      return null;
    }

    return _readAndCompress(file);
  }

  static Future<Uint8List?> pickFromGallery() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      return null;
    }

    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return null;
    }

    return _readAndCompress(file);
  }

  static Future<Uint8List> compress(Uint8List original) async {
    final compressed = await FlutterImageCompress.compressWithList(
      original,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: _jpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    return compressed.isEmpty ? original : Uint8List.fromList(compressed);
  }

  static Future<Uint8List?> recoverLostData() async {
    final lostData = await _picker.retrieveLostData();
    if (lostData.isEmpty || lostData.file == null) {
      return null;
    }

    return _readAndCompress(lostData.file!);
  }

  static Future<bool> requestPermissions({bool cameraOnly = false}) async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      return false;
    }

    if (cameraOnly) {
      return true;
    }

    final galleryStatus = await _requestGalleryPermission();
    return galleryStatus.isGranted || galleryStatus.isLimited;
  }

  static Future<bool> handlePermanentPermissionDenial(BuildContext context) async {
    final cameraDenied = await Permission.camera.isPermanentlyDenied;
    final photosDenied = await Permission.photos.isPermanentlyDenied;
    final storageDenied = await Permission.storage.isPermanentlyDenied;
    if (!cameraDenied && !photosDenied && !storageDenied) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permissão necessária'),
        content: const Text(
          'O acesso à câmera ou à galeria foi negado permanentemente. Abra as configurações do app para liberar a permissão e continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir configurações'),
          ),
        ],
      ),
    );

    if (openSettings == true) {
      return openAppSettings();
    }

    return false;
  }

  static Future<PermissionStatus> _requestGalleryPermission() async {
    if (!Platform.isAndroid) {
      return Permission.photos.request();
    }

    final photoStatus = await Permission.photos.request();
    if (photoStatus.isGranted || photoStatus.isLimited || photoStatus.isPermanentlyDenied) {
      return photoStatus;
    }

    return Permission.storage.request();
  }

  static Future<Uint8List> _readAndCompress(XFile file) async {
    final bytes = await file.readAsBytes();
    return compress(bytes);
  }
}