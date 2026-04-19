import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../models/feed_item.dart';
import '../../providers/feed_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feedItemsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('For You',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  fontFamily: 'PlusJakartaSans',
                )),
          ],
        ),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const _FeedSkeleton(),
        error: (e, _) => Center(
          child: Text('Could not load feed',
              style: TextStyle(color: Colors.white70)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyFeed();
          }
          return PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (i) {
              HapticFeedback.lightImpact();
              setState(() => _current = i);
            },
            itemBuilder: (context, i) {
              final item = items[i];
              return _FeedPage(
                item: item,
                isActive: i == _current,
                key: ValueKey(item.id),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Individual feed page ───────────────────────────────────────────────────

class _FeedPage extends StatelessWidget {
  const _FeedPage({required this.item, required this.isActive, super.key});

  final FeedItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media background
        if (item.isVideo)
          _VideoBackground(url: item.mediaUrl, isActive: isActive)
        else
          _PhotoBackground(url: item.mediaUrl),

        // Dark gradient at bottom for readability
        const _BottomGradient(),

        // "Popular in X" pill at top right
        if (item.isFromOtherArea)
          Positioned(
            top: 96,
            right: 16,
            child: _AreaPill(label: item.areaLabel!),
          ),

        // Info overlay bottom-left
        Positioned(
          left: 16,
          right: 72,
          bottom: 24,
          child: _InfoOverlay(item: item),
        ),

        // Action buttons right side
        Positioned(
          right: 8,
          bottom: 24,
          child: _ActionColumn(item: item),
        ),
      ],
    );
  }
}

// ── Video background ───────────────────────────────────────────────────────

class _VideoBackground extends StatefulWidget {
  const _VideoBackground({required this.url, required this.isActive});

  final String url;
  final bool isActive;

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  VideoPlayerController? _vc;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final vc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _vc = vc;
    await vc.initialize();
    vc.setLooping(true);
    vc.setVolume(0); // muted by default
    if (mounted) {
      setState(() => _ready = true);
      if (widget.isActive) vc.play();
    }
  }

  @override
  void didUpdateWidget(_VideoBackground old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _vc?.play();
    } else if (!widget.isActive && old.isActive) {
      _vc?.pause();
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _vc == null) {
      return const ColoredBox(color: Colors.black);
    }
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _vc!.value.isPlaying ? _vc!.pause() : _vc!.play();
        });
      },
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _vc!.value.size.width,
            height: _vc!.value.size.height,
            child: VideoPlayer(_vc!),
          ),
        ),
      ),
    );
  }
}

// ── Photo background ───────────────────────────────────────────────────────

class _PhotoBackground extends StatelessWidget {
  const _PhotoBackground({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const ColoredBox(color: Color(0xFF1A1A1A)),
      errorWidget: (context, url, err) => const ColoredBox(color: Color(0xFF1A1A1A)),
    );
  }
}

// ── Bottom gradient ────────────────────────────────────────────────────────

class _BottomGradient extends StatelessWidget {
  const _BottomGradient();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 280,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
          ),
        ),
      ),
    );
  }
}

// ── Area pill ──────────────────────────────────────────────────────────────

class _AreaPill extends StatelessWidget {
  const _AreaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text('Popular in $label',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'PlusJakartaSans')),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Info overlay ───────────────────────────────────────────────────────────

class _InfoOverlay extends StatelessWidget {
  const _InfoOverlay({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Author row
        Row(
          children: [
            if (item.authorPhotoUrl != null && item.authorPhotoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      CachedNetworkImageProvider(item.authorPhotoUrl!),
                  backgroundColor: Colors.white24,
                ),
              ),
            Flexible(
              child: Text(
                item.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  fontFamily: 'PlusJakartaSans',
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (item.caption != null && item.caption!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.caption!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: 'PlusJakartaSans',
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ).animate().slideY(begin: 0.15, duration: 350.ms, curve: Curves.easeOut);
  }
}

// ── Action column (right side) ─────────────────────────────────────────────

class _ActionColumn extends ConsumerWidget {
  const _ActionColumn({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PawButton(item: item),
        const SizedBox(height: 20),
        if (item.petId != null)
          _ActionButton(
            icon: Icons.pets_rounded,
            label: 'Profile',
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/pet/${item.petId}');
            },
          ),
        if (item.postId != null)
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Post',
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/neighborhood-news/post/${item.postId}');
            },
          ),
      ],
    );
  }
}

class _PawButton extends StatefulWidget {
  const _PawButton({required this.item});
  final FeedItem item;

  @override
  State<_PawButton> createState() => _PawButtonState();
}

class _PawButtonState extends State<_PawButton>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _liked = !_liked);
        _liked ? _anim.forward() : _anim.reverse();
      },
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.3)
            .animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut)),
        child: _ActionButton(
          icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '🐾',
          color: _liked ? Colors.pinkAccent : Colors.white,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontFamily: 'PlusJakartaSans',
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Color(0xFF1A1A1A)),
        Positioned(
          left: 16,
          right: 72,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmer(width: 120, height: 16),
              const SizedBox(height: 8),
              _shimmer(width: 220, height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shimmer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white24);
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pets_rounded, color: Colors.white30, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No videos yet in your area.',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
                fontFamily: 'PlusJakartaSans'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to share a pet video!',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontFamily: 'PlusJakartaSans'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/neighborhood-news/new'),
            icon: const Icon(Icons.add),
            label: const Text('Share a video'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}
