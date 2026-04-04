import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../config/firebase_bootstrap.dart';

Widget buildPawFileOrNetworkImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return Image.network(
      trimmed,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: Colors.grey.shade300,
        child: Icon(Icons.image_not_supported, size: (height ?? 48) * 0.4),
      ),
    );
  }
  if (trimmed.startsWith('gs://')) {
    if (!isFirebaseInitialized) {
      return ColoredBox(
        color: Colors.grey.shade300,
        child: Icon(Icons.image_not_supported, size: (height ?? 48) * 0.4),
      );
    }
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.refFromURL(trimmed).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ColoredBox(
            color: Colors.grey.shade300,
            child: Icon(Icons.image_not_supported, size: (height ?? 48) * 0.4),
          );
        }
        return Image.network(
          snapshot.data!,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: Colors.grey.shade300,
            child: Icon(Icons.image_not_supported, size: (height ?? 48) * 0.4),
          ),
        );
      },
    );
  }
  return ColoredBox(
    color: Colors.grey.shade300,
    child: Icon(Icons.image_not_supported, size: (height ?? 48) * 0.4),
  );
}
