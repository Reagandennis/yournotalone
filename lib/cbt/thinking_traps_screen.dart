import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import 'cbt_content.dart';
import '../toolkit/toolkit_ui.dart';

/// The field guide to unhelpful thinking: eleven traps, each with how it
/// sounds, an example, and the question that loosens it. Tap one to open
/// it; type a thought at the top to keep it in view while you look.
class ThinkingTrapsScreen extends StatefulWidget {
  const ThinkingTrapsScreen({super.key});

  @override
  State<ThinkingTrapsScreen> createState() => _ThinkingTrapsScreenState();
}

class _ThinkingTrapsScreenState extends State<ThinkingTrapsScreen> {
  final _thought = TextEditingController();
  String? _open;

  @override
  void dispose() {
    _thought.dispose();
    super.dispose();
  }

  Widget _trapCard(ThinkingTrap trap) {
    final c = context.brand;
    final open = _open == trap.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = open ? null : trap.name),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      // A soft disc: a white one would vanish on the card.
                      decoration: BoxDecoration(
                        color: c.tint(Pillars.black, 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        trap.icon,
                        size: 19,
                        color: c.accent(cbtAccent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trap.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.cbtQuoted(trap.soundsLike),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: c.textMuted,
                    ),
                  ],
                ),
                if (open) ...[
                  const SizedBox(height: 14),
                  _row(context.l10n.thinkingTrapsForExample, trap.example),
                  const SizedBox(height: 10),
                  _row(
                    context.l10n.thinkingTrapsAskYourself,
                    trap.ask,
                    strong: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String text, {bool strong = false}) {
    final c = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: c.accent(cbtAccent),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: strong ? FontWeight.w500 : FontWeight.w400,
            color: c.ink,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return ToolkitScaffold(
      accent: cbtAccent,
      title: l10n.thinkingTrapsTitle,
      children: [
        ToolkitSection(
          title: l10n.thinkingTrapsSectionTitle,
          subtitle: l10n.thinkingTrapsSectionBody,
        ),
        TextField(
          controller: _thought,
          maxLines: 2,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.thinkingTrapsThoughtLabel,
            counterText: '',
          ),
        ),
        if (_thought.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ToolkitNote(
            tint: c.tint(cbtAccent, 0.08),
            child: Text(
              l10n.thinkingTrapsWhichOne(
                l10n.cbtQuoted(_thought.text.trim()),
              ),
              style: TextStyle(
                fontSize: 13,
                color: c.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        for (final trap in thinkingTraps) _trapCard(trap),
        const SizedBox(height: 8),
        ToolkitNote(
          child: Text(
            l10n.thinkingTrapsFooter,
            style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}
