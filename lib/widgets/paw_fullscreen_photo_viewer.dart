import 'package:flutter/material.dart';

import 'paw_file_image.dart';

/// Opens [PawFullscreenPhotoViewer] (pinch/zoom + swipe when multiple URLs).
void showPawFullscreenPhotos(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  final list = urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) return;
  var i = initialIndex.clamp(0, list.length - 1);
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PawFullscreenPhotoViewer(urls: list, initialIndex: i),
    ),
  );
}

class PawFullscreenPhotoViewer extends StatefulWidget {
  const PawFullscreenPhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<PawFullscreenPhotoViewer> createState() => _PawFullscreenPhotoViewerState();
}

class _PawFullscreenPhotoViewerState extends State<PawFullscreenPhotoViewer> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final h = mq.height - MediaQuery.paddingOf(context).top - kToolbarHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.urls.length > 1
            ? Text('${_current + 1} / ${widget.urls.length}')
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: PawFileOrNetworkImage(
                path: widget.urls[i],
                fit: BoxFit.contain,
                width: mq.width,
                height: h,
              ),
            ),
          );
        },
      ),
    );
  }
}
