import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.5.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About ${AppConstants.appName}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: PawPartyColors.warmOak,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PawPartyColors.primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text('🍕', style: TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppConstants.appName,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(AppConstants.appTagline,
                    style: TextStyle(
                        fontSize: 15, color: PawPartyColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: PawPartyColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Version $_version',
                      style: TextStyle(
                          fontSize: 13, color: PawPartyColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '${AppConstants.appName} is the social app for pet parents. '
            'Discover nearby pets, host pizza parties for your furry friends, '
            'track memories in your pet\'s passport, and stay connected with '
            'your local pet community.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: PawPartyColors.textSecondary),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            url: AppConstants.termsOfServiceUrl,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '© ${DateTime.now().year} ${AppConstants.appName}. All rights reserved.',
              style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile(
      {required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: PawPartyColors.primary),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open link')),
            );
          }
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
