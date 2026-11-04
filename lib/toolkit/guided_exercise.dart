import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../meditation/meditation_catalog.dart';
import '../sounds/sound_player.dart';
import 'toolkit_art.dart';
import 'toolkit_content.dart';
import 'toolkit_ui.dart';

/// What a guided step asks for besides reading it.
enum GuidedInput { none, note, list }

/// One step of a [GuidedExercise]: a heading, what to do, and optionally a
/// timer and somewhere to write.
class GuidedStep {
  const GuidedStep({
    required this.title,
    required this.text,
    this.timerSeconds,
    this.input = GuidedInput.none,
    this.count = 3,
  });

  final String title;
  final String text;
  final int? timerSeconds;
  final GuidedInput input;

  /// How many lines a [GuidedInput.list] step has.
  final int count;
}

/// A tool or recovery exercise built in the content admin from steps,
/// rather than written as its own screen (`body.type: guided`).
class GuidedExercise {
  const GuidedExercise({
    required this.id,
    required this.title,
    required this.blurb,
    required this.minutes,
    required this.icon,
    required this.accent,
    required this.steps,
    this.art,
    this.premium = true,
  });

  final String id;
  final String title;
  final String blurb;
  final int minutes;
  final IconData icon;
  final Color accent;
  final List<GuidedStep> steps;

  /// The picture on its toolkit card; the hub's own when null.
  final ToolkitArtKind? art;
  final bool premium;

  /// The card a toolkit hub lists it with, drawn with [art] or [fallback].
  ToolkitTool toTool(ToolkitArtKind fallback) => ToolkitTool(
    title: title,
    blurb: blurb,
    minutes: minutes,
    icon: icon,
    art: art ?? fallback,
    premium: premium,
    open: (_) => GuidedExerciseScreen(exercise: this),
  );
}

class GuidedExerciseScreen extends StatefulWidget {
  const GuidedExerciseScreen({super.key, required this.exercise});

  final GuidedExercise exercise;

  @override
  State<GuidedExerciseScreen> createState() => _GuidedExerciseScreenState();
}

class _GuidedExerciseScreenState extends State<GuidedExerciseScreen> {
  int _index = 0;
  bool _saving = false;

  /// What was written, by step: one controller per line.
  late final List<List<TextEditingController>> _answers = [
    for (final step in widget.exercise.steps)
      [
        for (
          var i = 0;
          i <
              switch (step.input) {
                GuidedInput.none => 0,
                GuidedInput.note => 1,
                GuidedInput.list => step.count,
              };
          i++
        )
          TextEditingController(),
      ],
  ];

  List<GuidedStep> get _steps => widget.exercise.steps;
  bool get _finished => _index >= _steps.length;

  @override
  void dispose() {
    for (final step in _answers) {
      for (final c in step) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// Everything written, under each step's heading, for the journal.
  String get _summary => [
    for (var i = 0; i < _steps.length; i++)
      if (_answers[i].any((c) => c.text.trim().isNotEmpty))
        [
          _steps[i].title,
          for (final c in _answers[i])
            if (c.text.trim().isNotEmpty)
              _steps[i].input == GuidedInput.list
                  ? '• ${c.text.trim()}'
                  : c.text.trim(),
        ].join('\n'),
  ].join('\n\n');

  void _restart() => setState(() {
    _index = 0;
    for (final step in _answers) {
      for (final c in step) {
        c.clear();
      }
    }
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await toolkitSaveToJournal(
      context,
      title: widget.exercise.title,
      content: _summary,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercise = widget.exercise;
    if (_finished) return _done(context);
    final step = _steps[_index];
    final last = _index == _steps.length - 1;
    return ToolkitScaffold(
      accent: exercise.accent,
      title: exercise.title,
      bottom: Row(
        children: [
          if (_index > 0) ...[
            TextButton(
              onPressed: () => setState(() => _index--),
              child: Text(l10n.commonBack),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => _index++);
              },
              child: Text(last ? l10n.guidedFinish : l10n.commonContinue),
            ),
          ),
        ],
      ),
      children: [
        ToolkitStepHeader(
          step: _index + 1,
          of: _steps.length,
          title: step.title,
          hint: step.text,
        ),
        if (step.timerSeconds case final seconds?)
          // Keyed by step, so moving on starts the next timer afresh.
          _StepTimer(key: ValueKey(_index), seconds: seconds),
        if (step.input != GuidedInput.none) ...[
          const SizedBox(height: 8),
          for (final (i, c) in _answers[_index].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: c,
                minLines: step.input == GuidedInput.note ? 4 : 1,
                maxLines: step.input == GuidedInput.note ? 10 : 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: step.input == GuidedInput.note
                      ? l10n.guidedWriteHint
                      : '${i + 1}.',
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _done(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final accent = widget.exercise.accent;
    final wrote = _summary.isNotEmpty;
    return ToolkitScaffold(
      accent: accent,
      title: widget.exercise.title,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: c.tint(accent, 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 46, color: c.accent(accent)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.guidedDoneTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.guidedDoneBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
        ),
        const SizedBox(height: 28),
        if (wrote) ...[
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(l10n.guidedSaveToJournal),
          ),
          const SizedBox(height: 8),
        ] else ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonDone),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(onPressed: _restart, child: Text(l10n.toolkitGoAgain)),
      ],
    );
  }
}

/// A countdown the person starts when they're ready, with a chime at the
/// end. It never moves them on by itself.
class _StepTimer extends StatefulWidget {
  const _StepTimer({super.key, required this.seconds});

  final int seconds;

  @override
  State<_StepTimer> createState() => _StepTimerState();
}

class _StepTimerState extends State<_StepTimer> {
  late int _left = widget.seconds;
  Timer? _ticker;

  bool get _running => _ticker != null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _ticker!.cancel();
      setState(() => _ticker = null);
      return;
    }
    if (_left == 0) _left = widget.seconds;
    setState(() {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) {
          _ticker?.cancel();
          setState(() {
            _ticker = null;
            _left = 0;
          });
          SoundPlayer.instance.playOnce(chimeAsset);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final accent = c.accent(ToolkitTheme.of(context).accent);
    final minutes = _left ~/ 60, seconds = _left % 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: widget.seconds == 0 ? 0 : _left / widget.seconds,
                    strokeWidth: 8,
                    color: accent,
                    backgroundColor: c.border,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      _left == 0
                          ? l10n.guidedTimerDone
                          : '$minutes:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: _left == 0 ? 20 : 40,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _toggle,
              icon: Icon(
                _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _running
                    ? l10n.guidedTimerPause
                    : _left == 0
                    ? l10n.toolkitGoAgain
                    : l10n.guidedTimerStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
