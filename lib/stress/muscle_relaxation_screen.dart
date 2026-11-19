import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../toolkit/toolkit_ui.dart';
import '../toolkit/wall_clock_countdown.dart';
import 'stress_content.dart';

/// Progressive muscle relaxation: tense each group hard for a few
/// seconds, then let it go and notice the difference. The timer keeps
/// the count so the person can keep their eyes closed.
class MuscleRelaxationScreen extends StatefulWidget {
  const MuscleRelaxationScreen({
    super.key,
    this.tenseSeconds = 5,
    this.releaseSeconds = 10,
  });

  final int tenseSeconds;
  final int releaseSeconds;

  @override
  State<MuscleRelaxationScreen> createState() => _MuscleRelaxationScreenState();
}

class _MuscleRelaxationScreenState extends State<MuscleRelaxationScreen>
    with WallClockCountdown<MuscleRelaxationScreen> {
  bool _done = false;

  int get _groupSeconds => widget.tenseSeconds + widget.releaseSeconds;

  /// Into the whole run, by the wall clock rather than by counting ticks,
  /// so the groups are where they should be after the phone was locked.
  /// The last second holds until the clock's next check calls the end.
  int get _gone =>
      math.min(secondsGone, _groupSeconds * muscleGroups.length - 1);

  /// The group being worked, or -1 when not started.
  int get _index =>
      (countdown?.running ?? false) ? _gone ~/ _groupSeconds : -1;

  bool get _tensing => _gone % _groupSeconds < widget.tenseSeconds;

  /// Seconds left of tensing or of letting go.
  int get _left => _tensing
      ? widget.tenseSeconds - _gone % _groupSeconds
      : _groupSeconds - _gone % _groupSeconds;

  void _start() {
    setState(() => _done = false);
    startCountdown(
      Duration(seconds: _groupSeconds * muscleGroups.length),
      onDone: ({required late}) => setState(() => _done = true),
    );
  }

  void _stop() => setState(stopCountdown);

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final running = _index >= 0;
    final group = running ? muscleGroups[_index] : null;
    final l10n = context.l10n;
    return ToolkitScaffold(
      accent: stressAccent,
      title: l10n.muscleRelaxTitle,
      bottom: running
          ? OutlinedButton(onPressed: _stop, child: Text(l10n.commonStop))
          : ElevatedButton(
              onPressed: _start,
              child: Text(_done ? l10n.toolkitGoAgain : l10n.toolkitBegin),
            ),
      children: [
        if (!running)
          ToolkitSection(
            title: _done
                ? l10n.muscleRelaxDoneTitle
                : l10n.muscleRelaxIntroTitle,
            subtitle: _done
                ? l10n.muscleRelaxDoneBody
                : l10n.muscleRelaxIntroBody,
          ),
        if (!running) ...[
          for (final g in muscleGroups)
            ToolkitChoice(
              icon: g.icon,
              title: g.name,
              detail: g.tense,
              selected: false,
              onTap: () {},
            ),
        ] else ...[
          ToolkitStepHeader(
            step: _index + 1,
            of: muscleGroups.length,
            title: group!.name,
            hint: _tensing ? group.tense : l10n.muscleRelaxReleaseHint,
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              width: _tensing ? 150 : 220,
              height: _tensing ? 150 : 220,
              decoration: BoxDecoration(
                color: _tensing ? c.ink : c.tint(stressAccent, 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tensing
                          ? l10n.muscleRelaxTense
                          : l10n.muscleRelaxRelease,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _tensing ? c.onInk : c.ink,
                      ),
                    ),
                    Text(
                      '$_left',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: _tensing ? c.onInk : c.ink,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
