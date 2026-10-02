import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../journal/journal_repository.dart';

class _Step {
  const _Step(this.when, this.question, this.hint, this.icon, this.accent);

  final String when;
  final String question;
  final String hint;
  final IconData icon;
  final Color accent;
}

const _steps = [
  _Step(
    'In an hour',
    'You gave in. What does the next hour actually look like?',
    'Not the first five minutes — the hour.',
    Icons.schedule_rounded,
    Pillars.yellow,
  ),
  _Step(
    'Tomorrow morning',
    'You wake up. What\'s the first thing you remember?',
    'How does the day start from there?',
    Icons.wb_twilight_rounded,
    Pillars.red,
  ),
  _Step(
    'A week from now',
    'Where has this put you by next week?',
    'And what would the other choice have bought you?',
    Icons.calendar_month_rounded,
    Pillars.blue,
  ),
];

/// Play the tape forward: cravings only ever show you the first frame.
/// This walks the rest of the film, then keeps it in the journal so the
/// next craving argues with something you already wrote.
class TapeForwardScreen extends StatefulWidget {
  const TapeForwardScreen({super.key, this.journal});

  /// Injectable so the save path can be exercised without a backend.
  final JournalRepository? journal;

  @override
  State<TapeForwardScreen> createState() => _TapeForwardScreenState();
}

class _TapeForwardScreenState extends State<TapeForwardScreen> {
  late final _journal = widget.journal ?? JournalRepository();
  final _controllers = [
    for (var i = 0; i < _steps.length; i++) TextEditingController(),
  ];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasAnything =>
      _controllers.any((c) => c.text.trim().isNotEmpty);

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = StringBuffer();
    for (final (i, step) in _steps.indexed) {
      final answer = _controllers[i].text.trim();
      if (answer.isEmpty) continue;
      body.writeln(step.when);
      body.writeln(answer);
      body.writeln();
    }
    try {
      await _journal.create(
        title: 'Playing the tape forward',
        content: body.toString().trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your journal.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorMessage(e, 'Couldn\'t save — check your connection.')),
        ),
      );
    }
  }

  Widget _stepCard(int index) {
    final c = context.brand;
    final step = _steps[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.tint(step.accent, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon,
                      size: 17, color: c.accent(step.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.when,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.question,
              style: TextStyle(
                fontSize: 13.5,
                color: c.ink,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controllers[index],
              maxLines: null,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: step.hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: c.textMuted,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChip(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Play the tape forward',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                Text(
                  'A craving only ever shows you the first five minutes. '
                  'Watch the rest of the film before you decide — in your '
                  'own words, because yours are the ones you believe.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < _steps.length; i++) _stepCard(i),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: _hasAnything && !_saving ? _save : null,
                  child: Text(_saving ? 'Saving…' : 'Keep this in my journal'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Next time, this is waiting for you — written by the one '
                  'person the craving can\'t argue with.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
