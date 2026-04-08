import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_neighborhood_news_repository.dart';

class NeighborhoodNewsComposeScreen extends ConsumerStatefulWidget {
  const NeighborhoodNewsComposeScreen({super.key});

  @override
  ConsumerState<NeighborhoodNewsComposeScreen> createState() =>
      _NeighborhoodNewsComposeScreenState();
}

class _NeighborhoodNewsComposeScreenState
    extends ConsumerState<NeighborhoodNewsComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirestoreNeighborhoodNewsRepository.createPost(
        author: user,
        title: _title.text,
        body: _body.text,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your post is live for neighbors.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : user.neighborhoodKey.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Set your neighborhood in Profile before posting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawPartyColors.textSecondary),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Sharing with area: ${user.neighborhood ?? user.neighborhoodKey}',
                      style: TextStyle(
                        fontSize: 13,
                        color: PawPartyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Posts stay visible for about 2 weeks. Be kind — content can be reported.',
                      style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title (optional)',
                        hintText: 'Short headline',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _body,
                      minLines: 8,
                      maxLines: 16,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'What do you want neighbors to know?',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
    );
  }
}
