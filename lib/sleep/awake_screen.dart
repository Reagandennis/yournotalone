import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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
    final l10n = context.l10n;
    switch (_step) {
      case 1:
        return [
          ToolkitStepHeader(
            step: 1,
            of: 3,
            title: l10n.awakeStep1Title,
            hint: l10n.awakeStep1Hint,
          ),
          ToolkitNote(
            child: Text(
              l10n.awakeStep1Note,
              style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.55),
            ),
          ),
        ];
      case 2:
        return [
          ToolkitStepHeader(
            step: 2,
            of: 3,
            title: l10n.awakeStep2Title,
            hint: l10n.awakeStep2Hint,
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
                      l10n.awakeTimerHint,
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
            l10n.awakeOptionBoxBreathing,
            l10n.awakeOptionBoxBreathingDetail,
            () => openBreathing(
              context,
              'Box breathing',
              source: 'toolkit:sleep',
            ),
          ),
          _option(
            Icons.graphic_eq_rounded,
            l10n.awakeOptionSound,
            l10n.awakeOptionSoundDetail,
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SoundsScreen())),
          ),
          _option(
            Icons.self_improvement_rounded,
            l10n.awakeOptionDeepRest,
            l10n.awakeOptionDeepRestDetail,
            () => openMeditation(context, 'Deep rest', source: 'toolkit:sleep'),
          ),
          _option(
            Icons.menu_book_rounded,
            l10n.awakeOptionBook,
            l10n.awakeOptionBookDetail,
            () {},
          ),
        ];
      default:
        return [
          ToolkitStepHeader(
            step: 3,
            of: 3,
            title: l10n.awakeStep3Title,
            hint: l10n.awakeStep3Hint,
          ),
          ToolkitNote(
            child: Text(
              l10n.awakeStep3Note,
              style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.55),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget bottom = switch (_step) {
      1 => ElevatedButton(
        onPressed: () => setState(() => _step = 2),
        child: Text(l10n.awakeConfirmButton),
      ),
      2 =>
        _left == null
            ? ElevatedButton(
                onPressed: _startBreak,
                child: Text(l10n.awakeStartBreakButton),
              )
            : OutlinedButton(
                onPressed: () {
                  _timer?.cancel();
                  setState(() {
                    _left = null;
                    _step = 3;
                  });
                },
                child: Text(l10n.awakeSleepyButton),
              ),
      _ => ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.awakeGoodnightButton),
      ),
    };
    return ToolkitScaffold(
      accent: sleepAccent,
      title: l10n.awakeTitle,
      bottom: bottom,
      children: _body(),
    );
  }
}
