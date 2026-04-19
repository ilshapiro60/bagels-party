import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      q: 'How do I find pet parties near me?',
      a: 'Go to Discover → Events tab. Parties within 5 miles of your location '
          'are shown. Make sure your neighborhood is set in Profile → Settings.',
    ),
    (
      q: 'How do I host a party?',
      a: 'Tap the pizza slice button at the bottom of the screen. Fill in the '
          'party details, location, and food preferences. You get 3 free hostings; '
          'after that a small per-party fee applies.',
    ),
    (
      q: 'How do I invite friends to my party?',
      a: 'Open your party card on the Home screen and tap Invite. You can send '
          'invitations to your ZumiTok friends directly.',
    ),
    (
      q: 'What is the Passport?',
      a: 'Passport is your pet\'s party diary. Every party you attend or host '
          'can have a passport entry with photos, notes, and memories.',
    ),
    (
      q: 'How do I add or edit a pet?',
      a: 'Go to Profile, scroll to your pets, and tap the + button to add a '
          'new pet or tap an existing pet to edit their details.',
    ),
    (
      q: 'Can I delete my account?',
      a: 'Yes. Go to Profile → scroll to the bottom → Delete account. This '
          'permanently removes all your data within 30 days.',
    ),
    (
      q: 'How does the Feed work?',
      a: 'The Feed on your Home screen shows videos and photos from pets and '
          'parties in your area. If your area is low on content, popular posts '
          'from nearby areas are shown too.',
    ),
    (
      q: 'How do I report inappropriate content?',
      a: 'Open any neighborhood news post and tap the three-dot menu → Report. '
          'Our moderation team reviews all reports within 24 hours.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Frequently Asked Questions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          ..._faqs.map((faq) => _FaqTile(question: faq.q, answer: faq.a)),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Still need help?',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Send us an email and we\'ll get back to you within 1 business day.',
                  style: TextStyle(
                      fontSize: 14,
                      color: PawPartyColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _sendEmail(context),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: Text('Email ${AppConstants.supportEmail}'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {'subject': 'ZumiTok Support'},
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Could not open mail app. Email us at ${AppConstants.supportEmail}')),
        );
      }
    }
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      childrenPadding:
          const EdgeInsets.fromLTRB(20, 0, 20, 14),
      title: Text(question,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
      children: [
        Text(answer,
            style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: PawPartyColors.textSecondary)),
      ],
    );
  }
}
