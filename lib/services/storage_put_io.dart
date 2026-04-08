import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

Future<TaskSnapshot> storagePutLocalFile(
  Reference ref,
  String localPath,
  SettableMetadata metadata,
) async {
  return ref.putFile(File(localPath), metadata);
}
