import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../sounds/sounds_screen.dart';
import '../toolkit/toolkit_links.dart';
import '../toolkit/toolkit_ui.dart';
import 'sleep_content.dart';

/// The 20-minute rule, walked through in the middle of the night: notice
/// you're awake, get up and do something dull in low light, go back only
/// when sleepy. Dim, short, and no clock-watching.
class AwakeScreen extends StatefulWidget {
  const AwakeScreen({
    super.key,
    this.breakLength = const Duration(minutes: 15),
  });

  final Duration breakLength;

  @override
  State<AwakeScreen> createState() => _AwakeScreenState();
}

class _AwakeScreenState extends State<AwakeScreen> {
  int _step = 1;
  Timer? _timer;
  Duration? _left;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startBreak() {
    setState(() => _left = widget.breakLength);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _left! - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _timer?.cancel();
        setState(() {
          _left = null;
          _step = 3;
        });
      } else {
        setState(() => _left = next);
      }
    });
  }

  String _clock(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _option(
    IconData icon,
    String title,
    String detail,
    VoidCallback onTap,
  ) {
    return ToolkitChoice(
      icon: icon,
      title: title,
      detail: detail,
      selected: false,
      onTap: onTap,
      trailing: Icons.chevron_right_rounded,
    );
  }

  List<Widget> _body() {
    final c = context.brand;
    switch (_step) {
      case 1:
        return [
          const ToolkitStepHeader(
            step: 1,
            of: 3,
            title: 'Awake, and it\'s not passing?',
            hint:
                'Don\'t check the time — it only gives you sums to do. If '
                'it feels like you\'ve been lying here twenty minutes or '
                'more, that\'s long enough.',
          ),
          ToolkitNote(
            child: Text(
              'Lying in bed awake and frustrated teaches your brain that the '
              'bed is a place to be awake and frustrated. Getting up breaks '
              'that link. It feels backwards; it\'s the most reliable trick '
              'sleep clinics have.',
              style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.55),
            ),
          ),
        ];
      case 2:
        return [
          const ToolkitStepHeader(
            step: 2,
            of: 3,
            title: 'Get up. Low light, something dull.',
            hint:
                'Another room if you can. No bright screens, no news, no '
                'work. Boring is the goal — you\'re waiting for sleepiness '
                'to come back, not entertaining yourself.',
          ),
          if (_left != null) ...[
            ToolkitNote(
              tint: c.tint(sleepAccent, 0.08),
              child: Row(
                children: [
                  Text(
                    _clock(_left!),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Sleepy before this runs out? Go back to bed now — '
                      'sleepiness wins over the timer.',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _option(
            Icons.air_rounded,
            'Box breathing',
            'Four counts each way, in the dark.',
            () => openBreathing(
              context,
              'Box breathing',
              source: 'toolkit:sleep',
            ),
          ),
          _option(
            Icons.graphic_eq_rounded,
            'A quiet sound',
            'Rain or crickets, low, on a timer.',
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SoundsScreen())),
          ),
          _option(
            Icons.self_improvement_rounded,
            'Deep rest',
            'A long guided lie-down for when sleep won\'t come.',
            () => openMeditation(context, 'Deep rest', source: 'toolkit:sleep'),
          ),
          _option(
            Icons.menu_book_rounded,
            'A dull book',
            'Something you\'ve read before. Paper, if you have it.',
            () {},
          ),
        ];
      default:
        return [
          const ToolkitStepHeader(
            step: 3,
            of: 3,
            title: 'Back to bed when sleepy — not when the clock says',
            hint:
                'Heavy eyes, slow thoughts, a yawn. That\'s the signal. If '
                'it doesn\'t come, stay up a little longer; if you go back '
                'and it doesn\'t take, do the whole thing again.',
          ),
          ToolkitNote(
            child: Text(
              'Tomorrow: get up at your usual time however the night went. '
              'The sleep pressure you build will make tonight easier. One '
              'rough night is survivable; a drifting wake time isn\'t.',
              style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.55),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget bottom = switch (_step) {
      1 => ElevatedButton(
        onPressed: () => setState(() => _step = 2),
        child: const Text('Yes — I\'ve been awake a while'),
      ),
      2 =>
        _left == null
            ? ElevatedButton(
                onPressed: _startBreak,
                child: const Text('Start a 15-minute break'),
              )
            : OutlinedButton(
                onPressed: () {
                  _timer?.cancel();
                  setState(() {
                    _left = null;
                    _step = 3;
                  });
                },
                child: const Text('I\'m sleepy — back to bed'),
              ),
      _ => ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Goodnight'),
      ),
    };
    return ToolkitScaffold(
      accent: sleepAccent,
      title: 'Awake at 3am?',
      bottom: bottom,
      children: _body(),
    );
  }
}
