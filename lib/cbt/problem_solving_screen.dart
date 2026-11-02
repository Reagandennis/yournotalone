import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../journal/journal_repository.dart';
import '../toolkit/toolkit_ui.dart';
import 'cbt_content.dart';

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

  /// How a choice in [_whens] is shown, in the app's language.
  static String _whenLabel(AppLocalizations l10n, String when) =>
      switch (when) {
        'Today' => l10n.problemSolvingWhenToday,
        'Tomorrow' => l10n.problemSolvingWhenTomorrow,
        'This week' => l10n.problemSolvingWhenThisWeek,
        'Next week' => l10n.problemSolvingWhenNextWeek,
        _ => when,
      };

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

  String get _summary {
    final l10n = context.l10n;
    final when = _when;
    return l10n.problemSolvingSummary(
      _problem.text.trim(),
      _options.join('; '),
      '$_chosen',
      _firstStep.text.trim(),
      when == null ? 'null' : _whenLabel(l10n, when),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await toolkitSaveToJournal(
      context,
      title: context.l10n.problemSolvingPlanTitle,
      content: _summary,
      repository: widget.journal,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
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
            title: l10n.problemSolvingStep1Title,
            hint: l10n.problemSolvingStep1Hint,
          ),
          TextField(
            controller: _problem,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.problemSolvingStep1Field,
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ];
      case 2:
        return [
          ToolkitStepHeader(
            step: 2,
            of: _steps,
            title: l10n.problemSolvingStep2Title,
            hint: l10n.problemSolvingStep2Hint,
          ),
          TextField(
            controller: _option,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _addOption(),
            decoration: InputDecoration(
              labelText: l10n.problemSolvingOptionField,
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
                backgroundColor: c.card,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              title: Text(
                o,
                style: TextStyle(fontSize: 14, color: c.ink),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: c.textMuted,
                onPressed: () => setState(() {
                  _options.removeAt(i);
                  if (_chosen == o) _chosen = null;
                }),
              ),
            ),
        ];
      case 3:
        return [
          ToolkitStepHeader(
            step: 3,
            of: _steps,
            title: l10n.problemSolvingStep3Title,
            hint: l10n.problemSolvingStep3Hint,
          ),
          for (final o in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _chosen == o ? c.ink : c.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _chosen = o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _chosen == o
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 18,
                          color: _chosen == o ? c.onInk : c.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            o,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _chosen == o ? c.onInk : c.ink,
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
          ToolkitStepHeader(
            step: 4,
            of: _steps,
            title: l10n.problemSolvingStep4Title,
            hint: l10n.problemSolvingStep4Hint,
          ),
          ToolkitNote(
            child: Text(
              l10n.problemSolvingTrying('$_chosen'),
              style: TextStyle(
                fontSize: 13,
                color: c.textMuted,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _firstStep,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.problemSolvingFirstStepField,
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in _whens)
                ToolkitPill(
                  label: _whenLabel(l10n, w),
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
    final l10n = context.l10n;
    return ToolkitScaffold(
      accent: cbtAccent,
      title: l10n.problemSolvingTitle,
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
