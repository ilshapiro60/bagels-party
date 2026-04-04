import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../config/firebase_bootstrap.dart';

Widget _failedImageBox(double? width, double? height) {
  return ColoredBox(
    color: Colors.grey.shade300,
    child: Icon(
      Icons.broken_image,
      size: ((height ?? width ?? 48) * 0.45).clamp(20.0, 56.0),
    ),
  );
}

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
      errorBuilder: (context, error, stackTrace) =>
          _failedImageBox(width, height),
    );
  }
  if (trimmed.startsWith('gs://')) {
    if (!isFirebaseInitialized) {
      return _failedImageBox(width, height);
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
          return _failedImageBox(width, height);
        }
        return Image.network(
          snapshot.data!,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) =>
          _failedImageBox(width, height),
        );
      },
    );
  }
  final file = File(trimmed);
  if (!file.existsSync()) {
    return _failedImageBox(width, height);
  }
  return Image.file(
    file,
    fit: fit,
    width: width,
    height: height,
  );
}
