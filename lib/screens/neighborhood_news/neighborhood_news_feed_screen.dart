import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/neighborhood_news.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_neighborhood_news_repository.dart';
import '../../widgets/paw_file_image.dart';

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
                                          : 'No posts in the last 2 weeks.\nBe the first to share with neighbors!',
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
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final p = filtered[i];
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
      floatingActionButton: user != null && user.neighborhoodKey.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/neighborhood-news/new'),
              icon: const Icon(Icons.edit_note),
              label: const Text('Post'),
            )
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
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              Row(
                children: [
                  Icon(cat.icon, size: 16, color: PawPartyColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PawPartyColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateFormat.format(post.createdAt),
                    style: TextStyle(fontSize: 11, color: PawPartyColors.textHint),
                  ),
                  if (isOwner && onDelete != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.delete_outline, size: 18, color: PawPartyColors.textHint),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (post.title != null && post.title!.trim().isNotEmpty) ...[
                Text(
                  post.title!,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Text(
                post.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (post.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.photoUrls.length.clamp(0, 3),
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: PawFileOrNetworkImage(path: post.photoUrls[i]),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                post.authorDisplayName,
                style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
