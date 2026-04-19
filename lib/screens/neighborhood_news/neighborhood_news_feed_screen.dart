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
      floatingActionButton: user != null && user.neighborhoodKey.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/neighborhood-news/new'),
              child: const Icon(Icons.post_add_outlined),
            )
          : null,
      body: user == null
          ? const SizedBox.shrink()
          : user.neighborhoodKey.isEmpty
              ? _NoNeighborhoodMessage(onOpenProfile: () => context.push('/profile'))
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
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                            itemCount: totalCount,
                            separatorBuilder: (context, index) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final adsBefore = i == 0 ? 0 : (i) ~/ 6;
                              final isAd = i >= 5 && (i + 1) % 6 == 0;

                              if (isAd) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: NewsletterAdWidget(),
                                );
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

/// Full-bleed media carousel (photos then videos); swipe horizontally like Instagram.
class _PostMediaCarousel extends StatefulWidget {
  const _PostMediaCarousel({required this.post});

  final NeighborhoodNewsPost post;

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  late final PageController _pageController;
  int _page = 0;

  int get _itemCount => widget.post.photoUrls.length + widget.post.videoUrls.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_itemCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ColoredBox(
            color: Colors.black,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _itemCount,
              itemBuilder: (context, i) {
                final nPhotos = widget.post.photoUrls.length;
                if (i < nPhotos) {
                  return PawFileOrNetworkImage(
                    path: widget.post.photoUrls[i],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  );
                }
                final vi = i - nPhotos;
                return _NewsFeedInlineVideo(
                  url: widget.post.videoUrls[vi],
                  playing: i == _page,
                );
              },
            ),
          ),
        ),
        if (_itemCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _itemCount,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? PawPartyColors.primary
                        : PawPartyColors.textHint.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NewsFeedInlineVideo extends StatefulWidget {
  const _NewsFeedInlineVideo({required this.url, required this.playing});

  final String url;
  final bool playing;

  @override
  State<_NewsFeedInlineVideo> createState() => _NewsFeedInlineVideoState();
}

class _NewsFeedInlineVideoState extends State<_NewsFeedInlineVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        if (widget.playing) _controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
  }

  @override
  void didUpdateWidget(covariant _NewsFeedInlineVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || _error) return;
    if (widget.playing) {
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
    if (_error) {
      return Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white.withValues(alpha: 0.5), size: 40),
      );
    }
    if (!_ready) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
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

  void _openPostDetail(BuildContext context) {
    context.push(
      '/neighborhood-news/post/${post.id}',
      extra: post,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = post.newsCategory;
    final hasMedia = post.photoUrls.isNotEmpty || post.videoUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
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
              if (isOwner && onDelete != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.delete_outline, size: 18, color: PawPartyColors.textHint),
                  onPressed: onDelete,
                  tooltip: 'Delete post',
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              post.authorDisplayName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PawPartyColors.textPrimary),
            ),
          ),
        ),
        if (hasMedia) _PostMediaCarousel(post: post),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: ReactionBar(targetId: post.id),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPostDetail(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.title != null && post.title!.trim().isNotEmpty) ...[
                    Text(
                      post.title!,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (post.body.trim().isNotEmpty)
                    Text(
                      post.body,
                      style: TextStyle(fontSize: 14, height: 1.35, color: PawPartyColors.textPrimary),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: PawPartyColors.divider.withValues(alpha: 0.45)),
      ],
    );
  }
}
