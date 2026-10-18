import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PickedMapImage {
  const PickedMapImage({
    required this.file,
    required this.width,
    required this.height,
  });

  final XFile file;
  final int width;
  final int height;
}

class MapImageStorage {
  final ImagePicker _picker;

  MapImageStorage({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  Future<PickedMapImage?> pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return PickedMapImage(
          file: file,
          width: frame.image.width,
          height: frame.image.height,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<String> save(PickedMapImage image) async {
    final directory = await _mapsDirectory();
    await directory.create(recursive: true);
    final extension = _extension(image.file.name);
    final path =
        '${directory.path}/map_${DateTime.now().microsecondsSinceEpoch}$extension';
    final Uint8List bytes = await image.file.readAsBytes();
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> delete(String path) async {
    final directory = await _mapsDirectory();
    if (!path.startsWith('${directory.path}/')) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _mapsDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/maps');
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.img';
    final extension = name.substring(dot).toLowerCase();
    if (!RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)) return '.img';
    return extension;
  }
}
