import 'package:image_picker/image_picker.dart';

Future<String?> persistPickedFile(XFile file) async => file.path;
