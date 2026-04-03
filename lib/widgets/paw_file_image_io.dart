import 'dart:io';

import 'package:flutter/material.dart';

Widget buildPawFileOrNetworkImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
    );
  }
  final file = File(path);
  if (!file.existsSync()) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: const Icon(Icons.broken_image),
    );
  }
  return Image.file(
    file,
    fit: fit,
    width: width,
    height: height,
  );
}
