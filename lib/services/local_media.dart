import 'package:image_picker/image_picker.dart';

import 'local_media_stub.dart'
    if (dart.library.io) 'local_media_io.dart' as lm;

/// Copies picked files into app documents (mobile/desktop). On web, returns [XFile.path].
Future<String?> persistPickedFile(XFile file) => lm.persistPickedFile(file);
