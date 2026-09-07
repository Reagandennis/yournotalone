import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import 'breathing_screen.dart';
import 'meditation_catalog.dart';
import 'meditation_screen.dart';

/// Hub for the meditations & breathing section: quick breathing
/// exercises up top, timed meditations below.
class MeditationsScreen extends StatelessWidget {
  const MeditationsScreen({super.key});

  bool _guardPremium(BuildContext context, bool premium) {
    if (premium && !isPremiumUser()) {
      showUpgradeSheet(
        context,
        title: 'This session is part of Premium',
        message: 'Free includes a taste of each practice. Premium unlocks '
            'every session — and your first month is 80% off.',
      );
      return false;
    }
    return true;
  }

  Widget _breathCard(BuildContext context, BreathPattern pattern) {
    final locked = pattern.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: pattern.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (!_guardPremium(context, pattern.premium)) return;
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.air_rounded, size: 21, color: pattern.accent),
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Brand.ink,
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: pattern.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meditationCard(BuildContext context, Meditation meditation) {
    final locked = meditation.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Brand.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (!_guardPremium(context, meditation.premium)) return;
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
                    color: meditation.accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meditation.icon,
                      size: 21, color: meditation.accent),
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Brand.ink,
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
                        '${meditation.minutes} min · ${meditation.detail}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
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
                const Text(
                  'Meditations & breathing',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                const Text(
                  'A few minutes of guided calm — breathe along with the '
                  'circle, or settle into a quiet session.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Breathing exercises'),
                const SizedBox(height: 12),
                for (final pattern in breathPatterns)
                  _breathCard(context, pattern),
                const SizedBox(height: 14),
                const SectionHeader(title: 'Meditations'),
                const SizedBox(height: 12),
                for (final meditation in meditations)
                  _meditationCard(context, meditation),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
