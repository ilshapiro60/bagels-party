import 'package:flutter/material.dart';

import 'paw_file_image_stub.dart'
    if (dart.library.io) 'paw_file_image_io.dart' as pfi;

class PawFileOrNetworkImage extends StatelessWidget {
  const PawFileOrNetworkImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return pfi.buildPawFileOrNetworkImage(
      path,
      fit: fit,
      width: width,
      height: height,
    );
  }
}
