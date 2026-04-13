import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Loads a single JPEG frame from a video (local path or `http`/`https` URL).
/// On web, shows a static placeholder (native thumbnail generation is not used).
class PawVideoThumbnail extends StatefulWidget {
  const PawVideoThumbnail({
    super.key,
    required this.videoUrl,
    this.width = 52,
    this.height = 52,
    this.borderRadius = 6,
    this.timeMs = 800,
  });

  final String videoUrl;
  final double width;
  final double height;
  final double borderRadius;
  /// Offset into the clip; many encoders show a black frame at 0 ms.
  final int timeMs;

  @override
  State<PawVideoThumbnail> createState() => _PawVideoThumbnailState();
}

class _PawVideoThumbnailState extends State<PawVideoThumbnail> {
  Future<Uint8List?>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = _load();
  }

  @override
  void didUpdateWidget(PawVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _thumbFuture = _load();
    }
  }

  Future<Uint8List?>? _load() {
    if (kIsWeb || widget.videoUrl.isEmpty) return null;
    return VideoThumbnail.thumbnailData(
      video: widget.videoUrl,
      imageFormat: ImageFormat.JPEG,
      maxWidth: (widget.width * 3).round().clamp(120, 400),
      maxHeight: (widget.height * 3).round().clamp(120, 400),
      timeMs: widget.timeMs,
      quality: 72,
    );
  }

  double get _playIconSize => widget.width < 80 ? 22 : 36;

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black87,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            )
          : Icon(Icons.play_circle_outline,
              color: Colors.white70, size: _playIconSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _thumbFuture;

    Widget inner;
    if (kIsWeb || future == null) {
      inner = _placeholder();
    } else {
      inner = FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _placeholder(loading: true);
          }
          final bytes = snap.data;
          if (bytes == null || bytes.isEmpty) {
            return _placeholder();
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0x66000000)],
                  ),
                ),
              ),
              Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white70, size: _playIconSize),
              ),
            ],
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(width: widget.width, height: widget.height, child: inner),
    );
  }
}
