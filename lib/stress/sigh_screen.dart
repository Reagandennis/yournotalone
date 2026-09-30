import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../toolkit/toolkit_ui.dart';
import 'stress_content.dart';

/// One part of a sigh: how long it lasts, what to do, and how big the
/// circle is by the end of it.
class SighPhase {
  const SighPhase(this.label, this.hint, this.seconds, this.scale);

  final String label;
  final String hint;
  final int seconds;
  final double scale;
}

const sighPhases = <SighPhase>[
  SighPhase('Breathe in', 'Through the nose, most of the way.', 2, 0.85),
  SighPhase('One more sip', 'A short top-up, right to the top.', 1, 1.0),
  SighPhase(
    'Long breath out',
    'Slowly, through the mouth, until you\'re empty.',
    6,
    0.45,
  ),
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
    final phase = sighPhases[_phase];
    final scale = _running ? phase.scale : 0.6;
    return ToolkitScaffold(
      accent: stressAccent,
      title: 'Physiological sigh',
      bottom: _running
          ? OutlinedButton(onPressed: _stop, child: const Text('Stop'))
          : ElevatedButton(
              onPressed: _start,
              child: Text(_done ? 'Another round' : 'Start'),
            ),
      children: [
        ToolkitSection(
          title: _done
              ? 'That\'s the round'
              : _running
              ? 'Round $_round of ${widget.rounds}'
              : 'Two in, one long out',
          subtitle: _done
              ? 'Notice your shoulders and your jaw. Most people feel the '
                    'drop within a round or two. Use it any time — in a '
                    'meeting, in a queue, before a call.'
              : 'Breathe in through your nose, then take one more short sip '
                    'on top. Let it all out slowly through your mouth. That\'s '
                    'one. Follow the circle.',
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
                  decoration: const BoxDecoration(
                    color: Color(0x33F4BB40),
                    shape: BoxShape.circle,
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(seconds: _running ? phase.seconds : 1),
                  curve: Curves.easeInOut,
                  width: 150 * scale,
                  height: 150 * scale,
                  decoration: const BoxDecoration(
                    color: stressAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _running
                          ? phase.label
                          : _done
                          ? 'Done'
                          : 'Ready',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    if (_running)
                      Text(
                        '$_left',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
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
            phase.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Brand.textMuted,
              height: 1.5,
            ),
          ),
      ],
    );
  }
}
