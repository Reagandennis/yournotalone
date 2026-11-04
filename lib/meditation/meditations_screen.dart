import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../content/content_catalog.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import 'breathing_screen.dart';
import 'meditation_catalog.dart';
import 'meditation_screen.dart';

/// Hub for the meditations & breathing section: quick breathing
/// exercises up top, timed meditations below.
class MeditationsScreen extends StatelessWidget {
  const MeditationsScreen({super.key});

  bool _guardPremium(BuildContext context, bool premium, String item) {
    if (premium && !isPremiumUser()) {
      showUpgradeSheet(
        context,
        item: item,
        source: 'sheet:meditations',
        title: context.l10n.meditationsUpgradeTitle,
        message: context.l10n.meditationsUpgradeMessage(introOffer),
      );
      return false;
    }
    return true;
  }

  Widget _breathCard(BuildContext context, BreathPattern pattern) {
    final c = context.brand;
    final locked = pattern.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.tint(pattern.accent, 0.06),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (!_guardPremium(context, pattern.premium, pattern.title)) {
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BreathingScreen(pattern: pattern),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.chip,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.air_rounded,
                    size: 21,
                    color: c.accent(pattern.accent),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pattern.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 8),
                            const PremiumChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${pattern.rhythmLabel} · ${pattern.detail}',
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
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: c.accent(pattern.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meditationCard(BuildContext context, Meditation meditation) {
    final c = context.brand;
    final locked = meditation.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (!_guardPremium(
              context,
              meditation.premium,
              meditation.title,
            )) {
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MeditationScreen(meditation: meditation),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.tint(meditation.accent, 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meditation.icon,
                      size: 21, color: c.accent(meditation.accent)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meditation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 8),
                            const PremiumChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.meditationsItemMeta(
                          meditation.minutes,
                          meditation.detail,
                        ),
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PremiumBuilder(
        builder: (context, _) => _buildContent(context),
      );

  /// Wrapped by [PremiumBuilder] above, so this repaints the moment the
  /// entitlement changes — buying from inside the app used to leave the
  /// screen you bought from still locked.
  Widget _buildContent(BuildContext context) {
    final c = context.brand;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChip(),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.meditationsTitle,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                Text(
                  context.l10n.meditationsIntro,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(title: context.l10n.meditationsBreathingHeader),
                const SizedBox(height: 12),
                for (final pattern in breathPatternLibrary)
                  _breathCard(context, pattern),
                const SizedBox(height: 14),
                SectionHeader(title: context.l10n.meditationsMeditationsHeader),
                const SizedBox(height: 12),
                for (final meditation in meditationLibrary)
                  _meditationCard(context, meditation),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
