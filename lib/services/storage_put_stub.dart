import 'package:firebase_storage/firebase_storage.dart';

Future<TaskSnapshot> storagePutLocalFile(
  Reference ref,
  String localPath,
  SettableMetadata metadata,
) async {
  throw UnsupportedError('storagePutLocalFile is only used on IO platforms');
}
