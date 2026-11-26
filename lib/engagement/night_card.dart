import 'package:flutter/material.dart';

import '../brand.dart';
import '../discover/content_index.dart';
import '../discover/content_widgets.dart';
import '../discover/goals.dart';
import '../discover/taste_store.dart';
import '../l10n/l10n.dart';
import 'next_step.dart';

/// Home between midnight and five, in place of the health card and the
/// day's reading: one quiet thing for getting back to sleep (the tool for
/// lying awake, for those who can open it), and nothing else to do.
class NightCard extends StatelessWidget {
  const NightCard({super.key, required this.now, required this.premium});

  final DateTime now;
  final bool premium;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TasteStore.instance,
    builder: (context, _) {
      final step = chooseNextStep(
        now: now,
        premium: premium,
        goals: userGoals(),
      );
      if (step == null) return const SizedBox.shrink();
      final c = context.brand;
      final l10n = context.l10n;
      final item = step.item;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: c.tint(Pillars.blue, 0.06),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => openContent(context, item, source: 'home:night'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.nightCardTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: c.accent(Pillars.blue),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.line(l10n),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(item.icon, size: 22, color: c.accent(item.accent)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              item.meta(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: NotForMeButton(item: item, source: 'home:night'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
