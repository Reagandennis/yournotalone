import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
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

  @override
  Widget build(BuildContext context) {
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
                return Column(
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
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              sound.category.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: accent,
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
                              color: accent.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    Icon(sound.icon, size: 40, color: accent),
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        sound.detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Brand.textMuted,
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
                          icon: const Icon(
                            Icons.stop_rounded,
                            size: 30,
                            color: Brand.textMuted,
                          ),
                        ),
                        const SizedBox(width: 26),
                        Material(
                          color: active ? accent : Brand.ink,
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
                                color: Colors.white,
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
                          const Icon(
                            Icons.volume_down_rounded,
                            size: 20,
                            color: Brand.textMuted,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                activeTrackColor: accent,
                                inactiveTrackColor: Brand.border,
                                thumbColor: accent,
                                overlayColor: accent.withValues(alpha: 0.12),
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
                          const Icon(
                            Icons.volume_up_rounded,
                            size: 20,
                            color: Brand.textMuted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
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
  });

  final double t;
  final Sound sound;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = sound.category.accent;
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
        ..color = accent.withValues(alpha: 0.55 - layer * 0.17);
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
      oldDelegate.sound != sound;
}
