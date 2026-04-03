import 'package:image_picker/image_picker.dart';

import '../services/local_media.dart';

final _picker = ImagePicker();

Future<String?> pickPhotoFromGallery() async {
  final x = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    imageQuality: 88,
  );
  if (x == null) return null;
  return persistPickedFile(x);
}

Future<String?> pickPhotoFromCamera() async {
  final x = await _picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 2048,
    imageQuality: 88,
  );
  if (x == null) return null;
  return persistPickedFile(x);
}

Future<String?> pickVideoFromGallery() async {
  final x = await _picker.pickVideo(source: ImageSource.gallery);
  if (x == null) return null;
  return persistPickedFile(x);
}

Future<String?> pickVideoFromCamera() async {
  final x = await _picker.pickVideo(source: ImageSource.camera);
  if (x == null) return null;
  return persistPickedFile(x);
}
