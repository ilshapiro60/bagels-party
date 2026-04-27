import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/app_providers.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community Guidelines & Terms',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _section(
                      context,
                      'Zero tolerance for objectionable content',
                      'ZumiTok prohibits content that is hateful, violent, sexually explicit, '
                          'or otherwise objectionable. Violations result in immediate account removal.',
                    ),
                    _section(
                      context,
                      'No abusive behavior',
                      'Harassment, bullying, threats, or any abusive behaviour toward other members '
                          'is strictly prohibited and will result in account removal.',
                    ),
                    _section(
                      context,
                      'Location privacy',
                      'Your location is only shared when you actively check in on the Discover screen. '
                          'Check-in resets each session — you are never tracked automatically.',
                    ),
                    _section(
                      context,
                      'User-generated content',
                      'You are responsible for content you post. By posting, you confirm it does not '
                          'violate these guidelines, any applicable laws, or the rights of others.',
                    ),
                    _section(
                      context,
                      'Reporting',
                      'Use the Report button on any profile or post to flag content that breaks '
                          'these rules. All reports are reviewed.',
                    ),
                    _section(
                      context,
                      'Advertising',
                      'The Neighborhood News feed may contain Google-served ads. '
                          'Premium features are available via optional in-app purchase.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'By tapping "I Agree" you confirm that you have read and accept these terms.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: PawPartyColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(authStateProvider.notifier).acceptTerms();
                    context.go('/home');
                  },
                  child: const Text('I Agree — Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PawPartyColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
