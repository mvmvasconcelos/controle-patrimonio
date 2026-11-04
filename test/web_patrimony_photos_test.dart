import 'dart:typed_data';

import 'package:controle_patrimonio/screens/web_patrimony_pages.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:controle_patrimonio/services/web_photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

// 1x1 transparent PNG, valid for Image.memory.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

class _Repository extends WebInventoryRepository {
  _Repository()
      : super(
            client: MockClient(
                (_) async => throw StateError('Unexpected request')));

  final photos = <PatrimonyPhoto>[];
  final uploads = <Uint8List>[];
  final deleted = <int>[];
  Object? uploadError;
  Object? listError;
  var _nextId = 1;

  @override
  Future<List<PatrimonyPhoto>> fetchPhotos(String number) async {
    if (listError != null) throw listError!;
    return List.of(photos);
  }

  @override
  Future<Uint8List> fetchPhotoBytes(String number, int photoId) async => _pixel;

  @override
  Future<PatrimonyPhoto> uploadPhoto(String number, Uint8List bytes) async {
    if (uploadError != null) throw uploadError!;
    uploads.add(bytes);
    final photo = PatrimonyPhoto(id: _nextId++, number: number);
    photos.add(photo);
    return photo;
  }

  @override
  Future<void> deletePhoto(String number, int photoId) async {
    deleted.add(photoId);
    photos.removeWhere((p) => p.id == photoId);
  }
}

class _Picker implements WebPhotoPicker {
  final sources = <PhotoSource>[];
  Object? error;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    sources.add(source);
    if (error != null) throw error!;
    return Uint8List.fromList([0xff, 0xd8, 0xff, 1]);
  }
}

const _entry = InventoryEntry(
  number: '100',
  description: 'Mesa',
  room: 'Sala A',
  responsible: 'Ana',
  status: 'Ativo',
);

Future<(_Repository, _Picker)> _open(WidgetTester tester,
    {List<PatrimonyPhoto> initial = const []}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _Repository()..photos.addAll(initial);
  final picker = _Picker();
  await tester.pumpWidget(MaterialApp(
    home: WebPatrimonyDetailPage(
        repository: repository, entry: _entry, photoPicker: picker),
  ));
  await tester.pumpAndSettle();
  return (repository, picker);
}

void main() {
  testWidgets('lists the existing photos of the Patrimônio', (tester) async {
    await _open(tester, initial: [
      const PatrimonyPhoto(id: 1, number: '100'),
      const PatrimonyPhoto(id: 2, number: '100'),
    ]);
    expect(find.text('Fotos (2/3)'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('camera and file pick upload a resized photo and refresh',
      (tester) async {
    final (repository, picker) = await _open(tester);
    expect(find.text('Nenhuma foto anexada.'), findsOneWidget);

    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher arquivo'));
    await tester.pumpAndSettle();

    expect(picker.sources, [PhotoSource.camera, PhotoSource.file]);
    expect(repository.uploads, hasLength(2));
    expect(find.text('Fotos (2/3)'), findsOneWidget);
    expect(find.text('Foto adicionada.'), findsOneWidget);
  });

  testWidgets('upload buttons are disabled at the 3 photo limit',
      (tester) async {
    await _open(tester, initial: [
      for (var i = 1; i <= 3; i++) PatrimonyPhoto(id: i, number: '100'),
    ]);
    expect(find.text('Limite de 3 fotos atingido.'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Tirar foto'),
        matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows upload errors', (tester) async {
    final (repository, _) = await _open(tester);
    repository.uploadError = Exception('Foto maior que o limite de 5 MB');
    await tester.tap(find.text('Escolher arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Foto maior que o limite de 5 MB'), findsOneWidget);
    expect(find.text('Fotos (0/3)'), findsOneWidget);
  });

  testWidgets('shows picker errors', (tester) async {
    final (_, picker) = await _open(tester);
    picker.error = Exception('Não foi possível ler a imagem selecionada');
    await tester.tap(find.text('Escolher arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível ler a imagem selecionada'),
        findsOneWidget);
  });

  testWidgets('shows the load error instead of hiding photos', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository()..listError = Exception('Servidor fora');
    await tester.pumpWidget(MaterialApp(
      home: WebPatrimonyDetailPage(
          repository: repository, entry: _entry, photoPicker: _Picker()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Servidor fora'), findsOneWidget);
  });

  testWidgets('opens a photo enlarged and removes it after confirmation',
      (tester) async {
    final (repository, _) = await _open(tester,
        initial: [const PatrimonyPhoto(id: 1, number: '100')]);

    await tester.tap(find.byKey(const ValueKey('photo-1')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);
    await tester.tap(find.text('Remover').last);
    await tester.pumpAndSettle();

    expect(repository.deleted, [1]);
    expect(find.text('Fotos (0/3)'), findsOneWidget);
    expect(find.text('Foto removida.'), findsOneWidget);
  });
}
