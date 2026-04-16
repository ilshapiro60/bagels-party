import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildPawVideoThumb(String path, {double? height}) {
  return _VideoThumbStateful(path: path, height: height ?? 120);
}

bool _isNetworkVideoUrl(String path) {
  final p = path.trim();
  return p.startsWith('http://') || p.startsWith('https://');
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
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _startControllerForPath(widget.path);
  }

  @override
  void didUpdateWidget(covariant _VideoThumbStateful oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _loadFailed = false;
      _startControllerForPath(widget.path);
      setState(() {});
    }
  }

  void _startControllerForPath(String rawPath) {
    final path = rawPath.trim();
    if (path.isEmpty) {
      _loadFailed = true;
      return;
    }

    if (_isNetworkVideoUrl(path)) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(path))
        ..setLooping(false)
        ..initialize().then((_) {
          if (!mounted) return;
          _controller!.setVolume(0);
          _controller!.pause();
          setState(() {});
        }).catchError((_) {
          if (mounted) setState(() => _loadFailed = true);
        });
      return;
    }

    final file = File(path);
    if (file.existsSync()) {
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (!mounted) return;
          _controller!.setVolume(0);
          _controller!.pause();
          setState(() {});
        }).catchError((_) {
          if (mounted) setState(() => _loadFailed = true);
        });
    } else {
      _loadFailed = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return SizedBox(
        height: widget.height,
        width: widget.height,
        child: ColoredBox(
          color: Colors.black26,
          child: Icon(
            Icons.videocam_off_outlined,
            size: widget.height * 0.35,
            color: Colors.white70,
          ),
        ),
      );
    }
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
