import 'package:flutter/material.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
import '../therapy/session_format.dart';
import '../therapy/session_widgets.dart';
import 'care_repository.dart';
import 'care_widgets.dart';

const _durations = [30, 50, 60, 90];

/// Pick a therapist and a time for a request. Booking emails both the
/// client and the therapist. Pops with true once it's booked.
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.item, required this.repository});

  final AdminTherapyRequest item;
  final CareRepository repository;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  List<AdminTherapist>? _therapists;
  String? _error;
  String? _therapistId;
  DateTime? _date;
  TimeOfDay? _time;
  late int _duration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final request = widget.item.request;
    _therapistId = request.therapistId;
    _duration = _durations.contains(request.durationMinutes)
        ? request.durationMinutes
        : 50;
    final at = request.scheduledAt;
    if (at != null) {
      _date = DateUtils.dateOnly(at);
      _time = TimeOfDay.fromDateTime(at);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.repository.listTherapists();
      final topic = widget.item.request.topic;
      // Whoever specialises in the topic first, then whoever is least busy.
      final active = [
        for (final t in all)
          if (t.profile.active) t,
      ]..sort((a, b) {
          final aFits = a.profile.specialties.contains(topic) ? 0 : 1;
          final bFits = b.profile.specialties.contains(topic) ? 0 : 1;
          if (aFits != bFits) return aFits - bFits;
          return a.upcomingSessions - b.upcomingSessions;
        });
      if (mounted) {
        setState(() {
          _therapists = active;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = careErrorMessage(
            e, 'Couldn\'t load therapists — check your connection.'));
      }
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime? get _scheduledAt {
    final date = _date;
    final time = _time;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = _date;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          current != null && !current.isBefore(today) ? current : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _book() async {
    final therapistId = _therapistId;
    final at = _scheduledAt;
    if (therapistId == null || at == null) return;
    if (at.isBefore(DateTime.now())) {
      _say('That time has already passed.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.matchRequest(
        widget.item.request.id,
        therapistId: therapistId,
        scheduledAt: at,
        durationMinutes: _duration,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _say(careErrorMessage(e, 'Couldn\'t book — check your connection.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final request = widget.item.request;
    final therapists = _therapists;
    final note = request.note?.trim() ?? '';
    final payment = request.isFreeSession
        ? 'This is the client\'s free first session.'
        : request.needsPayment
            ? 'The client pays ${request.priceLabel} in the app before they '
                'can join.'
            : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(request.isPending ? 'Match request' : 'Change booking'),
      ),
      body: therapists == null
          ? _error != null
              ? LoadFailed(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    _load();
                  },
                )
              : const Center(child: CircularProgressIndicator())
          : ReadableWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: c.tint(Pillars.blue, 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.clientLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InfoLine(Icons.chat_bubble_outline_rounded, request.topic),
                        InfoLine(
                          Icons.calendar_month_rounded,
                          request.availability.isEmpty
                              ? 'Flexible'
                              : request.availability.join(' · '),
                        ),
                        if (note.isNotEmpty) InfoLine(Icons.notes_rounded, note),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Therapist'),
                  const SizedBox(height: 10),
                  if (therapists.isEmpty)
                    Text(
                      'No active therapists yet. Add one from the Therapists '
                      'tab first.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textMuted,
                        height: 1.5,
                      ),
                    )
                  else
                    for (final therapist in therapists)
                      _TherapistOption(
                        therapist: therapist,
                        selected: therapist.profile.id == _therapistId,
                        fitsTopic:
                            therapist.profile.specialties.contains(request.topic),
                        onTap: () =>
                            setState(() => _therapistId = therapist.profile.id),
                      ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'When'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerButton(
                          icon: Icons.event_rounded,
                          label: _date == null ? 'Pick a date' : formatDate(_date!),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerButton(
                          icon: Icons.schedule_rounded,
                          label: _time == null
                              ? 'Pick a time'
                              : _time!.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'In this phone\'s time zone. The client and therapist see '
                    'it in theirs.',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Length'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in _durations)
                        ChoicePill(
                          label: '$minutes min',
                          selected: _duration == minutes,
                          onTap: () => setState(() => _duration = minutes),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _therapistId == null ||
                            _scheduledAt == null ||
                            _saving
                        ? null
                        : _book,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(request.isPending ? 'Book session' : 'Save changes'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The client and therapist are emailed the details. $payment',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TherapistOption extends StatelessWidget {
  const _TherapistOption({
    required this.therapist,
    required this.selected,
    required this.fitsTopic,
    required this.onTap,
  });

  final AdminTherapist therapist;
  final bool selected;
  final bool fitsTopic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final profile = therapist.profile;
    final detail = [
      if (fitsTopic) 'Specialises in this',
      '${therapist.upcomingSessions} upcoming',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? c.tint(Pillars.black, 0.04) : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? c.ink : c.border,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TherapistAvatar(
                  name: profile.fullName,
                  photoUrl: profile.photoUrl,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 12,
                          color: fitsTopic ? c.blue : c.textMuted,
                        ),
                      ),
                      if (!therapist.hasAccount)
                        Text(
                          'Not signed in yet — they can\'t join until they do',
                          style: TextStyle(fontSize: 12, color: c.red),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? c.ink : c.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
