import 'package:flutter/material.dart';

/// Builds the map for a fixed [maxHeight] when embedded, or expands when [maxHeight] is null (fullscreen).
typedef ExpandableMapBuilder = Widget Function(
  BuildContext context,
  double? maxHeight,
);

/// Embeds a map at [collapsedHeight] with a control to open the same map full screen.
class ExpandableMapFrame extends StatelessWidget {
  const ExpandableMapFrame({
    super.key,
    required this.collapsedHeight,
    required this.fullscreenTitle,
    required this.mapBuilder,
    this.borderRadius = 20,
    this.expandable = true,
  });

  final double collapsedHeight;
  final String fullscreenTitle;
  final ExpandableMapBuilder mapBuilder;
  final double borderRadius;
  final bool expandable;

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(fullscreenTitle),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Back',
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: mapBuilder(ctx, null)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = mapBuilder(context, collapsedHeight);

    if (!expandable) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: map,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          map,
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              elevation: 2,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Full screen map',
                icon: const Icon(Icons.fullscreen),
                onPressed: () => _openFullscreen(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
