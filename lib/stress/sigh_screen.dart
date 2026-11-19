import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../toolkit/toolkit_ui.dart';
import '../toolkit/wall_clock_countdown.dart';
import 'stress_content.dart';

/// One part of a sigh: how long it lasts, what to do, and how big the
/// circle is by the end of it.
class SighPhase {
  const SighPhase(this.label, this.hint, this.seconds, this.scale);

  /// What to do, and how: strings looked up in the app's language.
  final String Function(AppLocalizations) label;
  final String Function(AppLocalizations) hint;
  final int seconds;
  final double scale;
}

String _inLabel(AppLocalizations l10n) => l10n.sighPhaseIn;
String _inHint(AppLocalizations l10n) => l10n.sighPhaseInHint;
String _sipLabel(AppLocalizations l10n) => l10n.sighPhaseSip;
String _sipHint(AppLocalizations l10n) => l10n.sighPhaseSipHint;
String _outLabel(AppLocalizations l10n) => l10n.sighPhaseOut;
String _outHint(AppLocalizations l10n) => l10n.sighPhaseOutHint;

const sighPhases = <SighPhase>[
  SighPhase(_inLabel, _inHint, 2, 0.85),
  SighPhase(_sipLabel, _sipHint, 1, 1.0),
  SighPhase(_outLabel, _outHint, 6, 0.45),
];

/// The physiological sigh: two inhales, one long exhale, a few times over.
/// The quickest way anyone has measured to bring a racing body down.
class SighScreen extends StatefulWidget {
  const SighScreen({super.key, this.rounds = 5});

  final int rounds;

  @override
  State<SighScreen> createState() => _SighScreenState();
}

class _SighScreenState extends State<SighScreen>
    with WallClockCountdown<SighScreen> {
  bool _done = false;

  static final _roundSeconds = sighPhases.fold(0, (sum, p) => sum + p.seconds);

  bool get _running => countdown?.running ?? false;

  int get _totalSeconds => _roundSeconds * widget.rounds;

  /// Where the rounds are — round from 1, phase, and seconds left in it —
  /// worked out from the time gone rather than counted tick by tick, so
  /// they're in the right place after the phone has been locked. The last
  /// second holds until the clock's next check calls the end.
  (int, int, int) get _position {
    final gone = math.min(secondsGone, _totalSeconds - 1);
    var into = gone % _roundSeconds;
    for (final (i, phase) in sighPhases.indexed) {
      if (into < phase.seconds) {
        return (gone ~/ _roundSeconds + 1, i, phase.seconds - into);
      }
      into -= phase.seconds;
    }
    return (widget.rounds, sighPhases.length - 1, 0);
  }

  void _start() {
    setState(() => _done = false);
    startCountdown(
      Duration(seconds: _totalSeconds),
      onDone: ({required late}) => setState(() => _done = true),
    );
  }

  void _stop() => setState(stopCountdown);

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final (round, phaseIndex, left) = _position;
    final phase = sighPhases[phaseIndex];
    final scale = _running ? phase.scale : 0.6;
    // The label runs past the inner circle as it shrinks, so in the dark it
    // stays light and the circle is a deep amber rather than bright yellow.
    final core = c.isDark ? const Color(0xFF946200) : stressAccent;
    final l10n = context.l10n;
    return ToolkitScaffold(
      accent: stressAccent,
      title: l10n.sighTitle,
      bottom: _running
          ? OutlinedButton(onPressed: _stop, child: Text(l10n.commonStop))
          : ElevatedButton(
              onPressed: _start,
              child: Text(_done ? l10n.sighAnotherRound : l10n.sighStart),
            ),
      children: [
        ToolkitSection(
          title: _done
              ? l10n.sighDoneTitle
              : _running
              ? l10n.sighRoundOf(round, widget.rounds)
              : l10n.sighIntroTitle,
          subtitle: _done ? l10n.sighDoneBody : l10n.sighIntroBody,
        ),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: Duration(seconds: _running ? phase.seconds : 1),
                  curve: Curves.easeInOut,
                  width: 240 * scale,
                  height: 240 * scale,
                  decoration: BoxDecoration(
                    color: c.tint(stressAccent, 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(seconds: _running ? phase.seconds : 1),
                  curve: Curves.easeInOut,
                  width: 150 * scale,
                  height: 150 * scale,
                  decoration: BoxDecoration(
                    color: core,
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _running
                          ? phase.label(l10n)
                          : _done
                          ? l10n.sighDone
                          : l10n.sighReady,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    if (_running)
                      Text(
                        '$left',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_running)
          Text(
            phase.hint(l10n),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
      ],
    );
  }
}
