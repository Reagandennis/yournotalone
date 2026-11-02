import 'package:flutter/material.dart';

import '../brand.dart';
import '../journal/journal_repository.dart';
import '../l10n/l10n.dart';
import 'cbt_content.dart';
import '../toolkit/toolkit_ui.dart';

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

/// How a feeling in [_feelings] is shown, in the app's language.
String _feelingLabel(AppLocalizations l10n, String feeling) =>
    switch (feeling) {
      'Anxious' => l10n.cbtFeelingAnxious,
      'Sad' => l10n.cbtFeelingSad,
      'Angry' => l10n.cbtFeelingAngry,
      'Ashamed' => l10n.cbtFeelingAshamed,
      'Guilty' => l10n.cbtFeelingGuilty,
      'Hopeless' => l10n.cbtFeelingHopeless,
      'Lonely' => l10n.cbtFeelingLonely,
      'Overwhelmed' => l10n.cbtFeelingOverwhelmed,
      _ => feeling,
    };

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
    final l10n = context.l10n;
    final feelings = [
      for (final f in _feelingSet) _feelingLabel(l10n, f),
    ].join(', ');
    final traps = _traps.isEmpty
        ? l10n.thoughtRecordNoneSpotted
        : _traps.join(', ');
    String orDash(TextEditingController c) =>
        c.text.trim().isEmpty ? '—' : c.text.trim();
    return l10n.thoughtRecordSummary(
      _situation.text.trim(),
      _thought.text.trim(),
      feelings,
      _before.round(),
      traps,
      orDash(_forEvidence),
      orDash(_against),
      _balanced.text.trim(),
      _after.round(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await toolkitSaveToJournal(
      context,
      title: context.l10n.thoughtRecordTitle,
      content: _summary,
      repository: widget.journal,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 4,
  }) {
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
    final c = context.brand;
    return Column(
      children: [
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: c.accent(cbtAccent),
          onChanged: onChanged,
        ),
        Text(
          context.l10n.thoughtRecordOutOf100(value.round()),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
      ],
    );
  }

  List<Widget> _body() {
    final c = context.brand;
    final l10n = context.l10n;
    switch (_step) {
      case 1:
        return [
          ToolkitStepHeader(
            step: 1,
            of: _steps,
            title: l10n.thoughtRecordStep1Title,
            hint: l10n.thoughtRecordStep1Hint,
          ),
          _field(_situation, l10n.thoughtRecordStep1Field),
        ];
      case 2:
        return [
          ToolkitStepHeader(
            step: 2,
            of: _steps,
            title: l10n.thoughtRecordStep2Title,
            hint: l10n.thoughtRecordStep2Hint,
          ),
          _field(_thought, l10n.thoughtRecordStep2Field),
        ];
      case 3:
        return [
          ToolkitStepHeader(
            step: 3,
            of: _steps,
            title: l10n.thoughtRecordStep3Title,
            hint: l10n.thoughtRecordStep3Hint,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _feelings)
                ToolkitPill(
                  label: _feelingLabel(l10n, f),
                  selected: _feelingSet.contains(f),
                  onTap: () => setState(
                    () => _feelingSet.contains(f)
                        ? _feelingSet.remove(f)
                        : _feelingSet.add(f),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _slider(_before, (v) => setState(() => _before = v)),
        ];
      case 4:
        return [
          ToolkitStepHeader(
            step: 4,
            of: _steps,
            title: l10n.thoughtRecordStep4Title,
            hint: l10n.thoughtRecordStep4Hint,
          ),
          for (final trap in thinkingTraps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _traps.contains(trap.name) ? c.ink : c.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(
                    () => _traps.contains(trap.name)
                        ? _traps.remove(trap.name)
                        : _traps.add(trap.name),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trap.icon,
                          size: 18,
                          color: _traps.contains(trap.name)
                              ? c.onInk
                              : c.accent(cbtAccent),
                        ),
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
                                      ? c.onInk
                                      : c.ink,
                                ),
                              ),
                              Text(
                                trap.soundsLike,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _traps.contains(trap.name)
                                      ? c.onInk.withValues(alpha: 0.7)
                                      : c.textMuted,
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
          ToolkitStepHeader(
            step: 5,
            of: _steps,
            title: l10n.thoughtRecordStep5Title,
            hint: l10n.thoughtRecordStep5Hint,
          ),
          _field(_forEvidence, l10n.thoughtRecordEvidenceFor, lines: 3),
          const SizedBox(height: 14),
          _field(_against, l10n.thoughtRecordEvidenceAgainst, lines: 3),
          const SizedBox(height: 14),
          if (_traps.isNotEmpty)
            ToolkitNote(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.thoughtRecordQuestionsWorthAsking,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final trap in thinkingTraps.where(
                    (t) => _traps.contains(t.name),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.cbtBullet(trap.ask),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
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
          ToolkitStepHeader(
            step: 6,
            of: _steps,
            title: l10n.thoughtRecordStep6Title,
            hint: l10n.thoughtRecordStep6Hint,
          ),
          ToolkitNote(
            child: Text(
              l10n.cbtQuoted(_thought.text.trim()),
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: c.textMuted,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _field(_balanced, l10n.thoughtRecordBalancedField),
        ];
      default:
        return [
          ToolkitStepHeader(
            step: 7,
            of: _steps,
            title: l10n.thoughtRecordStep7Title,
            hint: l10n.thoughtRecordStep7Hint,
          ),
          _slider(_after, (v) => setState(() => _after = v)),
          const SizedBox(height: 24),
          ToolkitNote(
            child: Text(
              _summary,
              style: TextStyle(
                fontSize: 12.5,
                color: c.ink,
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
    final l10n = context.l10n;
    return ToolkitScaffold(
      accent: cbtAccent,
      title: l10n.thoughtRecordTitle,
      bottom: Row(
        children: [
          if (_step > 1)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: Text(l10n.commonBack),
            ),
          const Spacer(),
          if (last)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonDone),
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
              child: Text(last ? l10n.cbtSaveToJournal : l10n.commonContinue),
            ),
          ),
        ],
      ),
      children: _body(),
    );
  }
}
