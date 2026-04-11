import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../models/neighborhood_news.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_neighborhood_news_repository.dart';
import '../../widgets/newsletter_ad_widget.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/reaction_bar.dart';

class NeighborhoodNewsFeedScreen extends ConsumerStatefulWidget {
  const NeighborhoodNewsFeedScreen({super.key});

  @override
  ConsumerState<NeighborhoodNewsFeedScreen> createState() =>
      _NeighborhoodNewsFeedScreenState();
}

class _NeighborhoodNewsFeedScreenState
    extends ConsumerState<NeighborhoodNewsFeedScreen> {
  String? _filterCategoryId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final postsAsync = ref.watch(neighborhoodNewsPostsProvider);
    final df = DateFormat.MMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area newsletter', style: TextStyle(fontSize: 18)),
        automaticallyImplyLeading: false,
        toolbarHeight: 48,
      ),
      body: user == null
          ? const SizedBox.shrink()
          : user.neighborhoodKey.isEmpty
              ? _NoNeighborhoodMessage(onOpenProfile: () => context.go('/profile'))
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(
                      child: postsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load posts: $e',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        data: (posts) {
                          final filtered = _filterCategoryId == null
                              ? posts
                              : posts.where((p) => p.category == _filterCategoryId).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.newspaper_outlined,
                                      size: 56,
                                      color: PawPartyColors.textHint,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _filterCategoryId != null
                                          ? 'No ${NewsCategory.fromId(_filterCategoryId).label} posts yet.'
                                          : 'No posts in the last 30 days.\nBe the first to share with neighbors!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: PawPartyColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final adCount = filtered.length >= 5
                              ? filtered.length ~/ 5
                              : 0;
                          final totalCount = filtered.length + adCount;

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: totalCount,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final adsBefore = i == 0 ? 0 : (i) ~/ 6;
                              final isAd = i >= 5 && (i + 1) % 6 == 0;

                              if (isAd) {
                                return const NewsletterAdWidget();
                              }

                              final postIndex = i - adsBefore;
                              if (postIndex >= filtered.length) {
                                return const SizedBox.shrink();
                              }
                              final p = filtered[postIndex];
                              return _PostCard(
                                post: p,
                                dateFormat: df,
                                isOwner: user.id == p.authorId,
                                onDelete: () => _confirmDeletePost(p),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: user != null && user.neighborhoodKey.isNotEmpty
          ? _buildActionPanel(context)
          : null,
    );
  }

  Future<void> _confirmDeletePost(NeighborhoodNewsPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirestoreNeighborhoodNewsRepository.deletePost(post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: NewsCategory.all.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            final isAll = _filterCategoryId == null;
            return FilterChip(
              selected: isAll,
              label: const Text('All'),
              onSelected: (_) => setState(() => _filterCategoryId = null),
              selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
              checkmarkColor: PawPartyColors.primary,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isAll ? FontWeight.w700 : FontWeight.w500,
                color: isAll ? PawPartyColors.primary : PawPartyColors.textSecondary,
              ),
              visualDensity: VisualDensity.compact,
            );
          }
          final cat = NewsCategory.all[i - 1];
          final selected = _filterCategoryId == cat.id;
          return FilterChip(
            avatar: Icon(cat.icon, size: 16),
            selected: selected,
            label: Text(cat.label),
            onSelected: (_) => setState(() {
              _filterCategoryId = selected ? null : cat.id;
            }),
            selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
            checkmarkColor: PawPartyColors.primary,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? PawPartyColors.primary : PawPartyColors.textSecondary,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton(
                icon: Icons.add,
                label: 'Post',
                onTap: () => context.push('/neighborhood-news/new'),
              ),
              _actionButton(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                onTap: () => _openMediaReel(context, filterVideo: false),
              ),
              _actionButton(
                icon: Icons.videocam_outlined,
                label: 'Videos',
                onTap: () => _openMediaReel(context, filterVideo: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PawPartyColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: PawPartyColors.primary, size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: PawPartyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static const _videoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv', '.m4v'];

  static bool _isVideoUrl(String url) {
    final lower = url.split('?').first.toLowerCase();
    return _videoExtensions.any((ext) => lower.endsWith(ext));
  }

  void _openMediaReel(BuildContext context, {required bool filterVideo}) {
    final postsAsync = ref.read(neighborhoodNewsPostsProvider);
    final posts = postsAsync.value ?? [];

    final allUrls = <String>[];
    for (final p in posts) {
      allUrls.addAll(p.photoUrls);
      allUrls.addAll(p.videoUrls);
    }

    final filtered = filterVideo
        ? allUrls.where(_isVideoUrl).toList()
        : allUrls.where((u) => !_isVideoUrl(u)).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(filterVideo
              ? 'No videos in the newsletter yet.'
              : 'No photos in the newsletter yet.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenMediaViewer(
          urls: filtered,
          initialIndex: 0,
          isVideo: filterVideo,
        ),
      ),
    );
  }
}

/// Full-screen media viewer.
/// Vertical swipe moves between items of the same type.
/// Horizontal swipe right returns to the previous screen.
class _FullScreenMediaViewer extends ConsumerStatefulWidget {
  const _FullScreenMediaViewer({
    required this.urls,
    required this.initialIndex,
    this.isVideo = false,
  });

  final List<String> urls;
  final int initialIndex;
  final bool isVideo;

  @override
  ConsumerState<_FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends ConsumerState<_FullScreenMediaViewer> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) {
                if (widget.isVideo) {
                  return _VideoPage(
                    url: widget.urls[i],
                    autoPlay: i == _currentPage,
                  );
                }
                return Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      widget.urls[i],
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white38),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: topPad + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: topPad + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 60,
              left: 16,
              right: 16,
              child: ReactionBar(
                targetId: 'media_${widget.urls[_currentPage].hashCode}',
                dark: true,
              ),
            ),
            if (_currentPage < widget.urls.length - 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: const Center(
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.url, required this.autoPlay});
  final String url;
  final bool autoPlay;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        if (widget.autoPlay) _controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
    _controller.setLooping(true);
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (widget.autoPlay && _initialized) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.white38, size: 48),
      );
    }
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white38),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!_controller.value.isPlaying)
                const Icon(Icons.play_arrow, color: Colors.white70, size: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoNeighborhoodMessage extends StatelessWidget {
  const _NoNeighborhoodMessage({required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_city_outlined, size: 56, color: PawPartyColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Set your neighborhood in Profile to read and post the area newsletter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PawPartyColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onOpenProfile,
              child: const Text('Open Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.dateFormat,
    this.isOwner = false,
    this.onDelete,
  });

  final NeighborhoodNewsPost post;
  final DateFormat dateFormat;
  final bool isOwner;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cat = post.newsCategory;
    return Material(
      color: PawPartyColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/neighborhood-news/post/${post.id}',
          extra: post,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PawPartyColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat.icon, size: 14, color: PawPartyColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PawPartyColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateFormat.format(post.createdAt),
                    style: TextStyle(fontSize: 10, color: PawPartyColors.textHint),
                  ),
                  if (isOwner && onDelete != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.delete_outline, size: 16, color: PawPartyColors.textHint),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              if (post.title != null && post.title!.trim().isNotEmpty) ...[
                Text(
                  post.title!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
              ],
              Text(
                post.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: PawPartyColors.textPrimary),
              ),
              if (post.photoUrls.isNotEmpty || post.videoUrls.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.photoUrls.length.clamp(0, 3) +
                        post.videoUrls.length.clamp(0, 2),
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      if (i < post.photoUrls.length.clamp(0, 3)) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: PawFileOrNetworkImage(path: post.photoUrls[i]),
                          ),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: Colors.black87,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.authorDisplayName,
                      style: TextStyle(fontSize: 11, color: PawPartyColors.textHint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ReactionBar(targetId: post.id),
            ],
          ),
        ),
      ),
    );
  }
}
