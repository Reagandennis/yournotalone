import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../brand_layout.dart';
import 'sound_player.dart';
import 'sounds_catalog.dart';

/// Full-screen "now playing" view: the sound's identity up top, a living
/// wave that moves with its character, and the media controls beneath.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.sound});

  final Sound sound;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  double _volume = SoundPlayer.instance.volume;

  Sound get sound => widget.sound;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    // Opening the player starts the sound (unless it's already on).
    // Deferred past the first frame: notifying play-state listeners
    // mid-navigation would mark widgets dirty during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && SoundPlayer.instance.nowPlaying.value != sound.asset) {
        _startPlayback();
      }
    });
  }

  Future<void> _startPlayback() async {
    try {
      await SoundPlayer.instance.play(sound.asset);
    } catch (e) {
      debugPrint('Sound playback failed for ${sound.asset}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t play that sound.')),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final player = SoundPlayer.instance;
    if (player.nowPlaying.value != sound.asset) {
      await _startPlayback();
    } else if (player.paused.value) {
      await player.resume();
    } else {
      await player.pause();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  /// Sleep timer. Five of the sounds are made for falling asleep to, and
  /// without this they play until the battery dies. [accent] is already
  /// resolved for the mode.
  Widget _sleepTimerRow(Color accent) {
    final c = context.brand;
    const options = [15, 30, 60];
    return ValueListenableBuilder<Duration?>(
      valueListenable: SoundPlayer.instance.sleepTimer,
      builder: (context, left, _) {
        if (left != null) {
          final minutes = left.inMinutes;
          final seconds = left.inSeconds % 60;
          return TextButton.icon(
            onPressed: () => SoundPlayer.instance.setSleepTimer(null),
            icon: const Icon(Icons.bedtime_rounded, size: 17),
            label: Text(
              'Stops in ${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')} · cancel',
            ),
            style: TextButton.styleFrom(foregroundColor: accent),
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_outlined, size: 16, color: c.textMuted),
            const SizedBox(width: 2),
            for (final minutes in options)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Material(
                  color: c.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: c.border, width: 1.2),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => SoundPlayer.instance
                        .setSleepTimer(Duration(minutes: minutes)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        '${minutes}m',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final accent = sound.category.accent;
    final player = SoundPlayer.instance;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedBuilder(
              animation: Listenable.merge([player.nowPlaying, player.paused]),
              builder: (context, _) {
                final active = player.isActive(sound.asset);
                // An ink button turns off-white in the dark, like the
                // logo's black pillar; a coloured one keeps its white icon.
                final inkButton = !active || accent == Pillars.black;
                return FlexibleColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                      child: Row(
                        children: [
                          const BackChip(),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: c.tint(accent, 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              sound.category.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.accent(accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Breathing icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: active ? 1.0 : 0.92),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, scale, child) => AnimatedBuilder(
                        animation: _wave,
                        builder: (context, child) {
                          final breathe = active
                              ? 1 +
                                  0.04 *
                                      math.sin(
                                          _wave.value * 2 * math.pi * 2)
                              : 1.0;
                          return Transform.scale(
                            scale: scale * breathe,
                            child: child,
                          );
                        },
                        child: Center(
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: c.tint(accent, 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: c.chip,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  sound.icon,
                                  size: 40,
                                  color: c.accent(accent),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      sound.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        sound.detail,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // The living wave
                    SizedBox(
                      height: 110,
                      child: AnimatedBuilder(
                        animation: _wave,
                        builder: (context, _) => TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: active ? 1 : 0.12),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, energy, _) => CustomPaint(
                            size: const Size(double.infinity, 110),
                            painter: _WavePainter(
                              t: _wave.value,
                              sound: sound,
                              energy: energy,
                              color: c.art(accent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Media controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Stop',
                          onPressed: () async {
                            await player.stop();
                            if (context.mounted) {
                              Navigator.of(context).maybePop();
                            }
                          },
                          icon: Icon(
                            Icons.stop_rounded,
                            size: 30,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(width: 26),
                        Material(
                          color: inkButton ? c.ink : accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _togglePlayPause,
                            child: SizedBox(
                              width: 76,
                              height: 76,
                              child: Icon(
                                active
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 40,
                                color: inkButton ? c.onInk : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 26),
                        const SizedBox(width: 46), // balances the stop button
                      ],
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Row(
                        children: [
                          Icon(
                            Icons.volume_down_rounded,
                            size: 20,
                            color: c.textMuted,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                activeTrackColor: c.accent(accent),
                                inactiveTrackColor: c.border,
                                thumbColor: c.accent(accent),
                                overlayColor: c.tint(accent, 0.12),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                ),
                              ),
                              child: Slider(
                                value: _volume,
                                onChanged: (v) {
                                  setState(() => _volume = v);
                                  SoundPlayer.instance.setVolume(v);
                                },
                              ),
                            ),
                          ),
                          Icon(
                            Icons.volume_up_rounded,
                            size: 20,
                            color: c.textMuted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sleepTimerRow(c.accent(accent)),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Layered travelling sine waves in the sound's accent colour. Each sound
/// has its own frequency, speed, and height; crickets pulse. [energy]
/// scales everything down to a near-flat line when paused.
class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.t,
    required this.sound,
    required this.energy,
    required this.color,
  });

  final double t;
  final Sound sound;
  final double energy;

  /// The sound's accent, resolved for the mode.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final phase = t * 2 * math.pi;
    var amp = size.height * 0.42 * sound.waveHeight * energy;
    if (sound.pulse) {
      final throb = math.sin(phase * 6);
      amp *= 0.55 + 0.45 * throb * throb;
    }

    for (var layer = 0; layer < 3; layer++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6 - layer * 0.6
        ..color = color.withValues(alpha: 0.55 - layer * 0.17);
      final freq = sound.waveFreq * (1 + layer * 0.35);
      final speed = sound.waveSpeed * (layer.isEven ? 1 : -1);
      final layerAmp = amp * (1 - layer * 0.28);
      final path = Path();
      for (double x = 0; x <= size.width; x += 3) {
        final u = x / size.width;
        final taper = math.sin(u * math.pi); // fade out at the edges
        final y = mid +
            layerAmp *
                taper *
                math.sin(u * freq * 2 * math.pi + phase * speed + layer);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.energy != energy ||
      oldDelegate.sound != sound ||
      oldDelegate.color != color;
}
