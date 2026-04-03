import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void openFullscreenLocalVideo(BuildContext context, String path) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => _FullScreenVideo(path: path),
      fullscreenDialog: true,
    ),
  );
}

class _FullScreenVideo extends StatefulWidget {
  const _FullScreenVideo({required this.path});

  final String path;

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  late final VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (mounted) {
          _c.play();
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _c.value.isInitialized
            ? AspectRatio(
                aspectRatio: _c.value.aspectRatio,
                child: VideoPlayer(_c),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
