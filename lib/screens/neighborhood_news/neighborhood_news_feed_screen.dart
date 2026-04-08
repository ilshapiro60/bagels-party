import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/neighborhood_news.dart';
import '../../providers/app_providers.dart';

class NeighborhoodNewsFeedScreen extends ConsumerWidget {
  const NeighborhoodNewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final postsAsync = ref.watch(neighborhoodNewsPostsProvider);
    final df = DateFormat.MMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area newsletter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: user == null
          ? const SizedBox.shrink()
          : user.neighborhoodKey.isEmpty
              ? _NoNeighborhoodMessage(onOpenProfile: () => context.go('/profile'))
              : postsAsync.when(
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
                    if (posts.isEmpty) {
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
                                'No posts in the last 2 weeks.\nBe the first to share with neighbors!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: PawPartyColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: posts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = posts[i];
                        return _PostCard(post: p, dateFormat: df);
                      },
                    );
                  },
                ),
      floatingActionButton: user != null && user.neighborhoodKey.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/neighborhood-news/new'),
              icon: const Icon(Icons.edit_note),
              label: const Text('Post'),
            )
          : null,
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
  const _PostCard({required this.post, required this.dateFormat});

  final NeighborhoodNewsPost post;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PawPartyColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          '/neighborhood-news/post/${post.id}',
          extra: post,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PawPartyColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.title != null && post.title!.trim().isNotEmpty)
                Text(
                  post.title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (post.title != null && post.title!.trim().isNotEmpty)
                const SizedBox(height: 6),
              Text(
                post.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '${post.authorDisplayName} · ${dateFormat.format(post.createdAt)}',
                style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
