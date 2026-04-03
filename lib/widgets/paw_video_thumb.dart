import 'package:flutter/material.dart';

import 'paw_video_thumb_stub.dart'
    if (dart.library.io) 'paw_video_thumb_io.dart' as pvt;

class PawVideoThumbnail extends StatelessWidget {
  const PawVideoThumbnail({
    super.key,
    required this.path,
    this.height = 120,
  });

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: pvt.buildPawVideoThumb(path, height: height),
    );
  }
}
