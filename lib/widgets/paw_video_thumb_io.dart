import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildPawVideoThumb(String path, {double? height}) {
  return _VideoThumbStateful(path: path, height: height ?? 120);
}

class _VideoThumbStateful extends StatefulWidget {
  const _VideoThumbStateful({required this.path, required this.height});

  final String path;
  final double height;

  @override
  State<_VideoThumbStateful> createState() => _VideoThumbStatefulState();
}

class _VideoThumbStatefulState extends State<_VideoThumbStateful> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final file = File(widget.path);
    if (file.existsSync()) {
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            _controller!.setVolume(0);
            _controller!.pause();
            setState(() {});
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
        Icon(
          Icons.play_circle_fill,
          size: 44,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ],
    );
  }
}
