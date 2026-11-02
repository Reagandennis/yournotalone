import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../toolkit/toolkit_ui.dart';
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

class _SighScreenState extends State<SighScreen> {
  Timer? _timer;
  bool _running = false;
  int _round = 0;
  int _phase = 0;
  int _left = 0;
  bool _done = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _done = false;
      _round = 1;
      _phase = 0;
      _left = sighPhases[0].seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (_left > 1) {
      setState(() => _left--);
      return;
    }
    // Phase over: next phase, next round, or finished.
    if (_phase < sighPhases.length - 1) {
      setState(() {
        _phase++;
        _left = sighPhases[_phase].seconds;
      });
    } else if (_round < widget.rounds) {
      setState(() {
        _round++;
        _phase = 0;
        _left = sighPhases[0].seconds;
      });
    } else {
      _timer?.cancel();
      setState(() {
        _running = false;
        _done = true;
      });
    }
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _round = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final phase = sighPhases[_phase];
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
              ? l10n.sighRoundOf(_round, widget.rounds)
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
                        '$_left',
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
