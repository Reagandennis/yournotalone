import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import 'player_screen.dart';
import 'sound_player.dart';
import 'sounds_catalog.dart';

/// Wellbeing sounds: looping ambient audio for focus, sleep, and calm.
/// Tapping a card opens the full player; the round button quick-toggles.
class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  SoundCategory? _filter;

  bool _guardPremium(Sound sound) {
    if (sound.premium && !isPremiumUser()) {
      showUpgradeSheet(
        context,
        title: 'This sound is part of Premium',
        message: 'Free includes one sound to try. Premium unlocks the whole '
            'library — and your first month is 80% off.',
      );
      return false;
    }
    return true;
  }

  void _openPlayer(Sound sound) {
    if (!_guardPremium(sound)) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(sound: sound)),
    );
  }

  Future<void> _quickToggle(Sound sound) async {
    if (!_guardPremium(sound)) return;
    try {
      await SoundPlayer.instance.toggle(sound.asset);
    } catch (e) {
      debugPrint('Sound playback failed for ${sound.asset}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t play that sound.')),
        );
      }
    }
  }

  Widget _chip(String label, SoundCategory? value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? Brand.ink : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? Brand.ink : Brand.border,
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _filter = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Brand.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _soundCard(Sound sound, {required bool active}) {
    final locked = sound.premium && !isPremiumUser();
    final accent = sound.category.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: accent.withValues(alpha: active ? 0.12 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: active
              ? BorderSide(color: accent, width: 1.4)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openPlayer(sound),
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
                  child: Icon(sound.icon, size: 21, color: accent),
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
                              sound.title,
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
                        active
                            ? 'Playing · ${sound.category.label}'
                            : '${sound.category.label} · ${sound.detail}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: active ? accent : Brand.textMuted,
                          fontWeight:
                              active ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: active ? accent : Brand.ink,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _quickToggle(sound),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        active
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
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
  Widget build(BuildContext context) {
    final visible = _filter == null
        ? soundsCatalog
        : [for (final s in soundsCatalog) if (s.category == _filter) s];
    final player = SoundPlayer.instance;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedBuilder(
              animation: Listenable.merge([player.nowPlaying, player.paused]),
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BackChip(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Wellbeing sounds',
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
                    'Loops that stay with you — pick one and let it run '
                    'while you focus, drift off, or settle down.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Brand.textMuted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      _chip('All', null),
                      for (final c in SoundCategory.values)
                        _chip(c.label, c),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final sound in visible)
                    _soundCard(sound, active: player.isActive(sound.asset)),
                  if (player.nowPlaying.value != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: player.stop,
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Stop sound'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
