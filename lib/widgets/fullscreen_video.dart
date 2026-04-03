import 'package:flutter/material.dart';

import 'fullscreen_video_stub.dart'
    if (dart.library.io) 'fullscreen_video_io.dart' as fv;

void openFullscreenLocalVideo(BuildContext context, String path) {
  fv.openFullscreenLocalVideo(context, path);
}
