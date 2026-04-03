import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

Future<String?> persistPickedFile(XFile file) async {
  final dir = await getApplicationDocumentsDirectory();
  final sub = Directory(p.join(dir.path, 'pawparty_media'));
  if (!await sub.exists()) {
    await sub.create(recursive: true);
  }
  final ext = p.extension(file.path);
  final safeExt = ext.isNotEmpty ? ext : '.bin';
  final name = '${const Uuid().v4()}$safeExt';
  final destPath = p.join(sub.path, name);
  await File(file.path).copy(destPath);
  return destPath;
}
