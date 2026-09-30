import 'package:flutter/material.dart';

import '../brand.dart';
import '../journal/journal_repository.dart';
import 'cbt_content.dart';
import 'cbt_ui.dart';

const _feelings = [
  'Anxious',
  'Sad',
  'Angry',
  'Ashamed',
  'Guilty',
  'Hopeless',
  'Lonely',
  'Overwhelmed',
];

/// The classic seven-column thought record, one column at a time: catch
/// the thought, check it against the evidence, and write a fairer one.
/// Nothing leaves the phone unless the person saves it to their journal.
class ThoughtRecordScreen extends StatefulWidget {
  const ThoughtRecordScreen({super.key, this.journal});

  /// Injectable so the flow can be exercised without a backend.
  final JournalRepository? journal;

  @override
  State<ThoughtRecordScreen> createState() => _ThoughtRecordScreenState();
}

class _ThoughtRecordScreenState extends State<ThoughtRecordScreen> {
  static const _steps = 7;
  int _step = 1;

  final _situation = TextEditingController();
  final _thought = TextEditingController();
  final _forEvidence = TextEditingController();
  final _against = TextEditingController();
  final _balanced = TextEditingController();
  final _feelingSet = <String>{};
  final _traps = <String>{};
  double _before = 70;
  double _after = 40;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_situation, _thought, _forEvidence, _against, _balanced]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        1 => _situation.text.trim().isNotEmpty,
        2 => _thought.text.trim().isNotEmpty,
        3 => _feelingSet.isNotEmpty,
        6 => _balanced.text.trim().isNotEmpty,
        _ => true,
      };

  String get _summary {
    final feelings = _feelingSet.join(', ');
    final traps = _traps.isEmpty ? 'none spotted' : _traps.join(', ');
    return 'Situation: ${_situation.text.trim()}\n'
        'Automatic thought: ${_thought.text.trim()}\n'
        'Feeling: $feelings — ${_before.round()}/100 before\n'
        'Thinking traps: $traps\n'
        'Evidence for: ${_forEvidence.text.trim().isEmpty ? '—' : _forEvidence.text.trim()}\n'
        'Evidence against: ${_against.text.trim().isEmpty ? '—' : _against.text.trim()}\n'
        'Balanced thought: ${_balanced.text.trim()}\n'
        'Feeling now: ${_after.round()}/100';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await cbtSaveToJournal(
      context,
      title: 'Thought record',
      content: _summary,
      repository: widget.journal,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  Widget _field(TextEditingController controller, String label,
      {int lines = 4}) {
    return TextField(
      controller: controller,
      maxLines: lines,
      maxLength: 600,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        counterText: '',
      ),
    );
  }

  Widget _slider(double value, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: cbtAccent,
          onChanged: onChanged,
        ),
        Text(
          '${value.round()} out of 100',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
          ),
        ),
      ],
    );
  }

  List<Widget> _body() {
    switch (_step) {
      case 1:
        return [
          const CbtStepHeader(
            step: 1,
            of: _steps,
            title: 'What was the situation?',
            hint: 'Just the facts, as a camera would have seen them. Where '
                'were you, who was there, what happened?',
          ),
          _field(_situation, 'e.g. Sent a message at 2pm, no reply by 9pm'),
        ];
      case 2:
        return [
          const CbtStepHeader(
            step: 2,
            of: _steps,
            title: 'What went through your mind?',
            hint: 'The first, quickest thought — the one that stung. Write '
                'it the way it sounded in your head.',
          ),
          _field(_thought, 'e.g. She\'s had enough of me'),
        ];
      case 3:
        return [
          const CbtStepHeader(
            step: 3,
            of: _steps,
            title: 'How did it make you feel?',
            hint: 'Pick what fits, then rate how strong it was.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _feelings)
                CbtPill(
                  label: f,
                  selected: _feelingSet.contains(f),
                  onTap: () => setState(() =>
                      _feelingSet.contains(f) ? _feelingSet.remove(f) : _feelingSet.add(f)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _slider(_before, (v) => setState(() => _before = v)),
        ];
      case 4:
        return [
          const CbtStepHeader(
            step: 4,
            of: _steps,
            title: 'Any thinking traps in there?',
            hint: 'Tap any that fit. Most hot thoughts have at least one.',
          ),
          for (final trap in thinkingTraps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _traps.contains(trap.name) ? Brand.ink : cbtCardColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _traps.contains(trap.name)
                      ? _traps.remove(trap.name)
                      : _traps.add(trap.name)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(trap.icon,
                            size: 18,
                            color: _traps.contains(trap.name)
                                ? Colors.white
                                : cbtAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trap.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _traps.contains(trap.name)
                                      ? Colors.white
                                      : Brand.ink,
                                ),
                              ),
                              Text(
                                trap.soundsLike,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _traps.contains(trap.name)
                                      ? Colors.white70
                                      : Brand.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ];
      case 5:
        return [
          const CbtStepHeader(
            step: 5,
            of: _steps,
            title: 'Check the evidence',
            hint: 'Facts, not feelings. What would a fair judge accept?',
          ),
          _field(_forEvidence, 'What supports the thought?', lines: 3),
          const SizedBox(height: 14),
          _field(_against, 'What doesn\'t fit with it?', lines: 3),
          const SizedBox(height: 14),
          if (_traps.isNotEmpty)
            CbtNote(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Questions worth asking',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final trap in thinkingTraps.where((t) => _traps.contains(t.name)))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${trap.ask}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ];
      case 6:
        return [
          const CbtStepHeader(
            step: 6,
            of: _steps,
            title: 'Write a fairer thought',
            hint: 'Not the cheerful opposite — something you could defend. '
                'It often starts "Even though…" or "It\'s possible that…".',
          ),
          CbtNote(
            child: Text(
              '“${_thought.text.trim()}”',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Brand.textMuted,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _field(_balanced, 'A more balanced way to see it'),
        ];
      default:
        return [
          const CbtStepHeader(
            step: 7,
            of: _steps,
            title: 'How strong is the feeling now?',
            hint: 'It rarely goes to zero. A few points down is the skill '
                'working.',
          ),
          _slider(_after, (v) => setState(() => _after = v)),
          const SizedBox(height: 24),
          CbtNote(
            child: Text(
              _summary,
              style: const TextStyle(
                fontSize: 12.5,
                color: Brand.ink,
                height: 1.55,
              ),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps;
    return CbtScaffold(
      title: 'Thought record',
      bottom: Row(
        children: [
          if (_step > 1)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Back'),
            ),
          const Spacer(),
          if (last)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: !_canContinue || _saving
                  ? null
                  : last
                      ? _save
                      : () => setState(() => _step++),
              child: Text(last ? 'Save to journal' : 'Continue'),
            ),
          ),
        ],
      ),
      children: _body(),
    );
  }
}
