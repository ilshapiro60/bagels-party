import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

String _extensionForPickedFile(XFile file) {
  var ext = p.extension(file.path);
  if (ext.isNotEmpty && ext != '.') return ext;
  final mime = file.mimeType?.toLowerCase();
  if (mime == 'image/png') return '.png';
  if (mime == 'image/webp') return '.webp';
  if (mime == 'image/gif') return '.gif';
  if (mime == 'image/heic' || mime == 'image/heif') return '.heic';
  if (mime != null && mime.startsWith('video/')) {
    if (mime.contains('quicktime')) return '.mov';
    if (mime.contains('webm')) return '.webm';
    return '.mp4';
  }
  return '.jpg';
}

/// Copies picked bytes into app documents. Uses [XFile.readAsBytes] so Android
/// content URIs and other non-[File]-readable paths work (plain [File.copy] does not).
Future<String?> persistPickedFile(XFile file) async {
  final dir = await getApplicationDocumentsDirectory();
  final sub = Directory(p.join(dir.path, 'pawparty_media'));
  if (!await sub.exists()) {
    await sub.create(recursive: true);
  }
  final safeExt = _extensionForPickedFile(file);
  final name = '${const Uuid().v4()}$safeExt';
  final destPath = p.join(sub.path, name);
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('Could not read the selected file.');
  }
  await File(destPath).writeAsBytes(bytes, flush: true);
  return destPath;
}
