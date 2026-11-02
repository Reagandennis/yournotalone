import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../meditation/meditations_screen.dart';
import 'cbt_content.dart';
import '../toolkit/toolkit_ui.dart';

/// 5-4-3-2-1 grounding: five things you can see, four you can feel, three
/// you can hear, two you can smell, one you can taste. Each tap counts one
/// down, so the exercise runs at the person's pace, not a timer's.
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _index = 0;
  int _found = 0;

  GroundingStep get _step => groundingSteps[_index];
  bool get _finished => _index >= groundingSteps.length;

  void _tap() {
    setState(() {
      _found++;
      if (_found >= _step.count) {
        _index++;
        _found = 0;
      }
    });
  }

  void _restart() => setState(() {
    _index = 0;
    _found = 0;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    if (_finished) {
      return ToolkitScaffold(
        accent: cbtAccent,
        title: l10n.groundingTitle,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.tint(cbtAccent, 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.spa_rounded,
                size: 42,
                color: c.accent(cbtAccent),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.groundingDoneTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.groundingDoneBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MeditationsScreen()),
            ),
            icon: const Icon(Icons.air_rounded),
            label: Text(l10n.groundingBreatheButton),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _restart,
            child: Text(l10n.toolkitGoAgain),
          ),
        ],
      );
    }
    final step = _step;
    final remaining = step.count - _found;
    return ToolkitScaffold(
      accent: cbtAccent,
      title: l10n.groundingTitle,
      bottom: ElevatedButton(
        onPressed: _tap,
        child: Text(
          remaining == 1 ? l10n.groundingFoundLast : l10n.groundingFoundOne,
        ),
      ),
      children: [
        ToolkitStepHeader(
          step: _index + 1,
          of: groundingSteps.length,
          title: l10n.groundingStepTitle(step.count, step.sense),
          hint: step.prompt,
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: c.card,
                shape: BoxShape.circle,
                border: Border.all(color: c.accent(cbtAccent), width: 6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(step.icon, size: 30, color: c.accent(cbtAccent)),
                  const SizedBox(height: 6),
                  Text(
                    '$remaining',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.groundingToGo(remaining),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < step.count; i++)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i < _found ? c.accent(cbtAccent) : c.border,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
