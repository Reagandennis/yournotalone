import 'package:flutter/material.dart';

import '../brand.dart';
import '../home/home_ui.dart';
import '../support/crisis_screen.dart';
import 'therapy_repository.dart';

const _topics = [
  'Anxiety & stress',
  'Low mood',
  'Relationships',
  'Grief & loss',
  'Addiction & recovery',
  'Not sure yet',
];

const _timeSlots = [
  'Weekday mornings',
  'Weekday afternoons',
  'Weekday evenings',
  'Weekends',
];

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _formatDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

String _formatDateTime(DateTime t) =>
    '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, '
    '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

/// Talk to a real therapist: request a private session, follow the
/// request as it's matched and confirmed, and see past sessions.
class TherapyScreen extends StatefulWidget {
  const TherapyScreen({super.key});

  @override
  State<TherapyScreen> createState() => _TherapyScreenState();
}

class _TherapyScreenState extends State<TherapyScreen> {
  final _repo = TherapyRepository();
  final _noteController = TextEditingController();

  List<TherapyRequest>? _requests;
  bool _failed = false;
  String? _topic;
  final _slots = <String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _requests = null;
      _failed = false;
    });
    try {
      final requests = await _repo.fetchRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _submit() async {
    final topic = _topic;
    if (topic == null) return;
    setState(() => _submitting = true);
    try {
      await _repo.requestSession(
        topic: topic,
        availability: [
          for (final slot in _timeSlots)
            if (_slots.contains(slot)) slot,
        ],
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      _topic = null;
      _slots.clear();
      _noteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent — we\'ll be in touch by email soon.'),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, 'Couldn\'t send your request — check your connection.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(TherapyRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
          'No problem — you can book again whenever you\'re ready, and '
          'your free first session stays yours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Brand.red),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.cancelRequest(request.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, 'Couldn\'t cancel — check your connection.')),
          ),
        );
      }
    }
  }

  Widget _pill(String label,
      {required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? const Color(0x0A191919) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? Brand.ink : Brand.border,
          width: selected ? 1.6 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Brand.ink : Brand.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _freeSessionBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0F3764CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 22, color: Brand.red),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your first session is on us',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'One full session with a licensed therapist, completely '
                  'free — no card needed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Brand.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingForm({required bool freeSession}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (freeSession) ...[
          _freeSessionBanner(),
          const SizedBox(height: 26),
        ],
        const SectionHeader(title: 'What would you like to focus on?'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in _topics)
              _pill(
                topic,
                selected: _topic == topic,
                onTap: () => setState(() => _topic = topic),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'When could you meet?'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in _timeSlots)
              _pill(
                slot,
                selected: _slots.contains(slot),
                onTap: () => setState(() {
                  _slots.contains(slot)
                      ? _slots.remove(slot)
                      : _slots.add(slot);
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Anything your therapist should know? (optional)',
            alignLabelWithHint: true,
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _topic == null || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(freeSession
                  ? 'Request my free session'
                  : 'Request a session'),
        ),
        const SizedBox(height: 10),
        const Text(
          'We\'ll email you within a day to match you with a licensed '
          'therapist and find a time that works for you.',
          style: TextStyle(fontSize: 12.5, color: Brand.textMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Brand.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Brand.ink,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(TherapyRequest request) {
    final confirmed = request.isConfirmed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0F3764CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  confirmed
                      ? Icons.event_available_rounded
                      : Icons.hourglass_top_rounded,
                  size: 22,
                  color: Brand.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      confirmed ? 'Session confirmed' : 'Request received',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      confirmed
                          ? 'Check your email for the meeting details.'
                          : 'We\'ll email you within a day to match you '
                              'with a licensed therapist.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Brand.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (confirmed && request.scheduledAt != null)
            _detailRow(Icons.schedule_rounded,
                _formatDateTime(request.scheduledAt!)),
          _detailRow(Icons.chat_bubble_outline_rounded, request.topic),
          if (request.availability.isNotEmpty)
            _detailRow(Icons.calendar_month_rounded,
                request.availability.join(' · ')),
          if (request.isFreeSession)
            _detailRow(Icons.favorite_rounded, 'First session — free'),
          if (request.isPending) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancel(request),
                style: TextButton.styleFrom(foregroundColor: Brand.red),
                child: const Text('Cancel request'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pastRow(TherapyRequest request) {
    final completed = request.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: Brand.border, width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.topic,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(request.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Brand.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            completed ? 'Completed' : 'Cancelled',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: completed ? Brand.blue : Brand.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    return Scaffold(
      appBar: AppBar(title: const Text('Talk to a therapist')),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Couldn\'t load — check your connection.',
                      style: TextStyle(fontSize: 14, color: Brand.textMuted),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            : requests == null
                ? const Center(child: CircularProgressIndicator())
                : _body(requests),
      ),
    );
  }

  Widget _body(List<TherapyRequest> requests) {
    final active = requests.where((r) => r.isActive).firstOrNull;
    final past = [...requests.where((r) => !r.isActive)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        const Text(
          'You don\'t have to do this alone',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 16),
        const Text(
          'Private one-on-one sessions with licensed therapists, right '
          'from here. Tell us a little about what you need and we\'ll '
          'match you with the right person.',
          style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.6),
        ),
        const SizedBox(height: 26),
        if (active != null)
          _activeCard(active)
        else
          _bookingForm(
            freeSession: _repo.isFreeSessionAvailable(requests),
          ),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionHeader(title: 'Past requests'),
          const SizedBox(height: 12),
          for (final request in past) _pastRow(request),
        ],
        const SizedBox(height: 24),
        const CrisisFooter(
          trailing: ' This app can\'t replace emergency care.',
        ),
      ],
    );
  }
}
