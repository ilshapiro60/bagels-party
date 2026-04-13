import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/chat_safety_report.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_chat_safety_repository.dart';

class ChatSafetyModerationScreen extends ConsumerWidget {
  const ChatSafetyModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final reportsAsync = ref.watch(chatSafetyPendingReportsProvider);
    final df = DateFormat.yMMMd().add_jm();

    if (user == null || !user.isModerator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation')),
        body: const Center(
          child: Text('You do not have access to the report queue.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message safety reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Text(
                'No pending reports.',
                style: TextStyle(color: PawPartyColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = reports[i];
              return _ReportCard(report: r, dateFormat: df);
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.dateFormat});

  final ChatSafetyReport report;
  final DateFormat dateFormat;

  Future<void> _resolve(BuildContext context, {required bool acknowledge}) async {
    try {
      await FirestoreChatSafetyRepository.resolveReport(
        reportId: report.id,
        acknowledge: acknowledge,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              acknowledge ? 'Marked reviewed and closed.' : 'Report dismissed.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: PawPartyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PawPartyColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reported member: ${report.reportedUid}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Conversation: ${report.conversationId}',
              style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
            ),
            if (report.contextSnippet != null && report.contextSnippet!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Context: ${report.contextSnippet}',
                style: TextStyle(color: PawPartyColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Text('Reason: ${report.reason}'),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(report.createdAt)} · reporter ${report.reporterId}',
              style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolve(context, acknowledge: false),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _resolve(context, acknowledge: true),
                    child: const Text('Reviewed'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
