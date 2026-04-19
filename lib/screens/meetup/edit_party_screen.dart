import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../models/meetup.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_meetup_repository.dart';

class EditPartyScreen extends ConsumerStatefulWidget {
  const EditPartyScreen({super.key, required this.meetup});
  final Meetup meetup;

  @override
  ConsumerState<EditPartyScreen> createState() => _EditPartyScreenState();
}

class _EditPartyScreenState extends ConsumerState<EditPartyScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _dateTime;
  late int _duration;
  late String _theme;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.meetup.title);
    _descCtrl = TextEditingController(text: widget.meetup.description ?? '');
    _dateTime = widget.meetup.dateTime;
    _duration = widget.meetup.durationMinutes;
    _theme = widget.meetup.theme;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party name cannot be empty.')),
      );
      return;
    }
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirestoreMeetupRepository.updateMeetup(
        meetupId: widget.meetup.id,
        actingHostId: user.id,
        title: title,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dateTime: _dateTime,
        durationMinutes: _duration,
      );
      ref.invalidate(upcomingMeetupsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _dateTime = DateTime(d.year, d.month, d.day, _dateTime.hour, _dateTime.minute);
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (t == null) return;
    setState(() {
      _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, t.hour, t.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, MMM d');
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Party'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Party name'),
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          const Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.eventThemes.map((t) {
              final selected = t == _theme;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                onSelected: (_) => setState(() => _theme = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Date & time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(dateFmt.format(_dateTime)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(timeFmt.format(_dateTime)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [60, 90, 120, 180, 240].map((m) {
              final label = m < 60
                  ? '$m min'
                  : m % 60 == 0
                      ? '${m ~/ 60}h'
                      : '${m ~/ 60}h ${m % 60}m';
              return ChoiceChip(
                label: Text(label),
                selected: _duration == m,
                onSelected: (_) => setState(() => _duration = m),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
