import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/neighborhood_news.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_neighborhood_news_repository.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/paw_file_image.dart';
import '../../widgets/reaction_bar.dart';

String? _snippetForReport(NeighborhoodNewsPost post) {
  final t = post.title?.trim();
  if (t != null && t.isNotEmpty) {
    return t.length > 120 ? t.substring(0, 120) : t;
  }
  final b = post.body;
  if (b.isEmpty) return null;
  return b.length <= 80 ? b : b.substring(0, 80);
}

class NeighborhoodNewsPostDetailScreen extends ConsumerStatefulWidget {
  const NeighborhoodNewsPostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  final String postId;
  final NeighborhoodNewsPost? initialPost;

  @override
  ConsumerState<NeighborhoodNewsPostDetailScreen> createState() =>
      _NeighborhoodNewsPostDetailScreenState();
}

class _NeighborhoodNewsPostDetailScreenState
    extends ConsumerState<NeighborhoodNewsPostDetailScreen> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  NeighborhoodNewsPost? _resolvePost(List<NeighborhoodNewsPost> list) {
    for (final p in list) {
      if (p.id == widget.postId) return p;
    }
    return widget.initialPost;
  }

  Future<void> _sendComment(NeighborhoodNewsPost post) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final t = _comment.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirestoreNeighborhoodNewsRepository.addComment(
        postId: post.id,
        author: user,
        body: t,
      );
      _comment.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildCategoryBadge(NeighborhoodNewsPost post) {
    final cat = post.newsCategory;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: PawPartyColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icon, size: 16, color: PawPartyColors.secondary),
            const SizedBox(width: 6),
            Text(
              cat.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PawPartyColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(BuildContext context, List<String> urls) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => _showFullscreenPhoto(context, urls, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 180,
                height: 180,
                child: PawFileOrNetworkImage(path: urls[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoGallery(BuildContext context, List<String> urls) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () => _showFullscreenVideo(context, urls, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 180,
                height: 140,
                color: Colors.black87,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline, color: Colors.white70, size: 44),
                    const SizedBox(height: 6),
                    Text(
                      'Video ${i + 1}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullscreenPhoto(BuildContext context, List<String> urls, int initial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenPhotoViewer(urls: urls, initialIndex: initial),
      ),
    );
  }

  void _showFullscreenVideo(BuildContext context, List<String> urls, int initial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoViewer(urls: urls, initialIndex: initial),
      ),
    );
  }

  Future<void> _report(NeighborhoodNewsPost post) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final reason = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report post'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'What is wrong with this post?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    try {
      await FirestoreNeighborhoodNewsRepository.submitReport(
        reporter: user,
        postId: post.id,
        areaKey: post.areaKey,
        reason: reason.text,
        postTitleSnippet: _snippetForReport(post),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks — moderators will review.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final postsAsync = ref.watch(neighborhoodNewsPostsProvider);
    final commentsAsync = ref.watch(neighborhoodNewsCommentsProvider(widget.postId));
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        actions: [
          postsAsync.maybeWhen(
            data: (list) {
              final post = _resolvePost(list);
              if (post == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'report') _report(post);
                  if (v == 'delete') _confirmDeletePost(post);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                  if (user?.id == post.authorId)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final post = _resolvePost(list);
          if (post == null) {
            return const Center(child: Text('Post not found or older than 30 days.'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildCategoryBadge(post),
                    const SizedBox(height: 12),
                    if (post.title != null && post.title!.trim().isNotEmpty)
                      Text(
                        post.title!,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    if (post.title != null && post.title!.trim().isNotEmpty)
                      const SizedBox(height: 12),
                    Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
                    if (post.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPhotoGallery(context, post.photoUrls),
                    ],
                    if (post.videoUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildVideoGallery(context, post.videoUrls),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '${post.authorDisplayName} · ${df.format(post.createdAt)}',
                      style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ReactionBar(targetId: post.id),
                    const SizedBox(height: 20),
                    Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Comments: $e'),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return Text(
                            'No comments yet.',
                            style: TextStyle(color: PawPartyColors.textHint),
                          );
                        }
                        return Column(
                          children: comments.map((c) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: PawPartyColors.surfaceVariant.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.authorDisplayName,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        if (user?.id == c.authorId || user?.isModerator == true)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            onPressed: () async {
                                              await FirestoreNeighborhoodNewsRepository
                                                  .deleteComment(
                                                postId: post.id,
                                                commentId: c.id,
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.body),
                                    Text(
                                      df.format(c.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: PawPartyColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comment,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sending ? null : () => _sendComment(post),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FullscreenVideoViewer extends StatefulWidget {
  const _FullscreenVideoViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<_FullscreenVideoViewer> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.urls.length > 1
            ? Text('Video ${_current + 1} / ${widget.urls.length}')
            : const Text('Video'),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          return _DetailVideoPage(
            url: widget.urls[i],
            autoPlay: i == _current,
          );
        },
      ),
    );
  }
}

class _DetailVideoPage extends StatefulWidget {
  const _DetailVideoPage({required this.url, required this.autoPlay});
  final String url;
  final bool autoPlay;

  @override
  State<_DetailVideoPage> createState() => _DetailVideoPageState();
}

class _DetailVideoPageState extends State<_DetailVideoPage> {
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
  void didUpdateWidget(_DetailVideoPage old) {
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

class _FullscreenPhotoViewer extends StatefulWidget {
  const _FullscreenPhotoViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: Center(
              child: Image.network(
                widget.urls[i],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
