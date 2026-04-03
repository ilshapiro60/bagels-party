import 'package:flutter/material.dart';

void openFullscreenLocalVideo(BuildContext context, String path) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Video playback is limited on this platform.')),
  );
}
