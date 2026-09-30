import 'package:flutter/material.dart';

import '../brand.dart';
import '../journal/journal_repository.dart';
import 'cbt_ui.dart';

/// Structured problem solving: name the problem precisely, list every
/// option without judging, pick one, and plan a first step small enough
/// to take this week. Worry goes round in circles; this goes forward.
class ProblemSolvingScreen extends StatefulWidget {
  const ProblemSolvingScreen({super.key, this.journal});

  final JournalRepository? journal;

  @override
  State<ProblemSolvingScreen> createState() => _ProblemSolvingScreenState();
}

class _ProblemSolvingScreenState extends State<ProblemSolvingScreen> {
  static const _steps = 4;
  int _step = 1;
  final _problem = TextEditingController();
  final _option = TextEditingController();
  final _options = <String>[];
  String? _chosen;
  final _firstStep = TextEditingController();
  String? _when;
  bool _saving = false;

  static const _whens = ['Today', 'Tomorrow', 'This week', 'Next week'];

  @override
  void dispose() {
    _problem.dispose();
    _option.dispose();
    _firstStep.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        1 => _problem.text.trim().isNotEmpty,
        2 => _options.length >= 2,
        3 => _chosen != null,
        _ => _firstStep.text.trim().isNotEmpty && _when != null,
      };

  void _addOption() {
    final text = _option.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _options.add(text);
      _option.clear();
    });
  }

  String get _summary => 'Problem: ${_problem.text.trim()}\n'
      'Options considered: ${_options.join('; ')}\n'
      'Chosen: $_chosen\n'
      'First step: ${_firstStep.text.trim()} — $_when';

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await cbtSaveToJournal(
      context,
      title: 'Problem-solving plan',
      content: _summary,
      repository: widget.journal,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  List<Widget> _body() {
    switch (_step) {
      case 1:
        return [
          const CbtStepHeader(
            step: 1,
            of: _steps,
            title: 'What exactly is the problem?',
            hint: 'One problem, in one sentence, specific enough to act on. '
                '"Money" is a worry; "I\'m £300 short for rent on the 1st" '
                'is a problem.',
          ),
          TextField(
            controller: _problem,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'The problem, precisely',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ];
      case 2:
        return [
          const CbtStepHeader(
            step: 2,
            of: _steps,
            title: 'List every option',
            hint: 'Don\'t judge them yet — bad ideas loosen up good ones. '
                'Aim for at least three, including one you\'d never do.',
          ),
          TextField(
            controller: _option,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _addOption(),
            decoration: InputDecoration(
              labelText: 'An option',
              counterText: '',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _addOption,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, o) in _options.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: CircleAvatar(
                radius: 13,
                backgroundColor: cbtCardColor,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
              ),
              title: Text(o, style: const TextStyle(fontSize: 14, color: Brand.ink)),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Brand.textMuted,
                onPressed: () => setState(() {
                  _options.removeAt(i);
                  if (_chosen == o) _chosen = null;
                }),
              ),
            ),
        ];
      case 3:
        return [
          const CbtStepHeader(
            step: 3,
            of: _steps,
            title: 'Pick one to try',
            hint: 'Not the perfect one — the one that\'s good enough and '
                'that you\'d actually do. You can come back to the others.',
          ),
          for (final o in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _chosen == o ? Brand.ink : cbtCardColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _chosen = o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Icon(
                          _chosen == o
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 18,
                          color: _chosen == o ? Colors.white : Brand.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            o,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _chosen == o ? Colors.white : Brand.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ];
      default:
        return [
          const CbtStepHeader(
            step: 4,
            of: _steps,
            title: 'What\'s the first step?',
            hint: 'Something that takes under twenty minutes and needs no '
                'one\'s permission. Then decide when.',
          ),
          CbtNote(
            child: Text(
              'Trying: $_chosen',
              style: const TextStyle(fontSize: 13, color: Brand.textMuted, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _firstStep,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'First step',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in _whens)
                CbtPill(
                  label: w,
                  selected: _when == w,
                  onTap: () => setState(() => _when = w),
                ),
            ],
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps;
    return CbtScaffold(
      title: 'Problem solving',
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
