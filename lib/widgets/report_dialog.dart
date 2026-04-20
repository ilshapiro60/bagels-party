import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../providers/app_providers.dart';
import '../services/firestore_chat_safety_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _reasons = [
  'Spam',
  'Harassment or bullying',
  'Inappropriate content',
  'Fake account',
  'Other',
];

/// Shows a report dialog and submits to Firestore on confirm.
/// [reportedUid] — UID of the person being reported.
/// [reportContext] — 'profile' or 'post'.
/// [contextId] — optional post/content ID.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String reportedUid,
  String reportContext = 'profile',
  String? contextId,
}) async {
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) => const _ReportDialog(),
  );
  if (submitted == null || !context.mounted) return;

  final uid = ref.read(authStateProvider).user?.id;
  if (uid == null) return;

  try {
    await FirestoreChatSafetyRepository.submitProfileReport(
      reporterId: uid,
      reportedUid: reportedUid,
      reason: submitted,
      reportContext: reportContext,
      contextId: contextId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report submitted. Thank you for keeping ZumiTok safe.'),
          backgroundColor: PawPartyColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    }
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selected;
  late final TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    _detailController = TextEditingController();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selected != null &&
        (_selected != 'Other' || _detailController.text.trim().isNotEmpty);

    return AlertDialog(
      title: const Text('Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this?',
              style: TextStyle(fontSize: 14, color: PawPartyColors.textSecondary),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _reasons
                    .map((r) => RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: r,
                          title: Text(r, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
              ),
            ),
            if (_selected == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _detailController,
                autofocus: true,
                maxLines: 3,
                maxLength: 280,
                decoration: const InputDecoration(
                  hintText: 'Please describe the issue…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () {
                  final reason = _selected == 'Other'
                      ? _detailController.text.trim()
                      : _selected!;
                  Navigator.pop(context, reason);
                }
              : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
