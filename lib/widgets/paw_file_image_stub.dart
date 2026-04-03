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
  return ColoredBox(
    color: Colors.grey.shade300,
    child: Icon(Icons.image_not_supported, size: (height ?? 48) * 0.4),
  );
}
