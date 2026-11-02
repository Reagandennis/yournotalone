import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../brand.dart';
import '../discover/content_index.dart';
import 'background_spec.dart';
import 'calm_visuals.dart';
import 'scene_library.dart';
import 'scene_painters.dart';

/// Where every scene starts, and where a still one stays: far enough in
/// that the waves and lights have spread out.
const sceneStillTime = 12.0;

/// One background, drawn and — unless something says not to — slowly
/// moving.
///
/// It holds still (one frame, no ticker) when the phone asks to reduce
/// motion, when Calm visuals is off, when [animate] is false, and while
/// the app is in the background. Off-screen routes stop it too: the
/// ticker is muted by [TickerMode]. Moving, it repaints at most 30 times
/// a second, through a [RepaintBoundary] and a painter that repaints off
/// a clock rather than rebuilding widgets.
class SceneBackground extends StatefulWidget {
  const SceneBackground({
    super.key,
    required this.spec,
    this.intensity = 1,
    this.swell,
    this.animate = true,
  });

  final BackgroundSpec spec;

  /// 0–1, scales how present the scene is (a finished session dims it).
  final double intensity;

  /// Read each frame for a 0–1 swell, so the scene can breathe with the
  /// breathing screen's circle.
  final double Function()? swell;

  /// False for a preview that never moves.
  final bool animate;

  @override
  State<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends State<SceneBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// A little under 1/30 s, so a 60 Hz display paints every other frame
  /// rather than every third when a frame lands a hair early.
  static const _frameSeconds = 1 / 30 - 0.002;

  final _clock = SceneClock(sceneStillTime);
  late final Ticker _ticker = createTicker(_tick);

  /// Scene seconds already run when the ticker last started; a paused
  /// scene picks up where it stopped.
  double _before = sceneStillTime;
  bool _foreground = true;

  ScenePainter? _painter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    CalmVisualsSetting.instance.addListener(_sync);
  }

  static bool _isForeground(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    _ => true,
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = _isForeground(state);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SceneBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Starts or stops the ticker to match everything that says whether
  /// the scene may move.
  void _sync() {
    if (!mounted) return;
    final moving =
        widget.animate &&
        _foreground &&
        CalmVisualsSetting.instance.enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (moving && !_ticker.isActive) {
      _before = _clock.time;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final now =
        _before + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (now - _clock.time < _frameSeconds) return;
    _clock.tick(now, widget.swell?.call() ?? 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CalmVisualsSetting.instance.removeListener(_sync);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = resolvePalette(context.brand, widget.spec.palette);
    final old = _painter;
    // A new painter only when what it draws changes; between those, it
    // repaints off the clock.
    if (old == null ||
        old.spec != widget.spec ||
        old.intensity != widget.intensity ||
        !listEquals(old.colors, colors)) {
      _painter = ScenePainter.of(
        widget.spec,
        colors,
        _clock,
        intensity: widget.intensity,
      );
    }
    return RepaintBoundary(
      child: CustomPaint(painter: _painter, size: Size.infinite),
    );
  }
}

/// The background for one item: the one the person picked for it, else
/// the item's own, else its kind's default (see [SceneLibrary]).
///
/// Without [child] it is only the scene, for a screen that already
/// stacks its own layers. With one it paints the page colour, the scene,
/// then [child] on top — so a screen can use it as its body.
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({
    super.key,
    required this.itemId,
    required this.kind,
    this.intensity = 1,
    this.swell,
    this.child,
  });

  /// The content id, `kind:Title` (see `ContentItem.id`).
  final String itemId;
  final ContentKind kind;
  final double intensity;
  final double Function()? swell;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scene = ListenableBuilder(
      listenable: Listenable.merge([
        SceneLibrary.instance,
        CalmVisualsSetting.instance,
      ]),
      builder: (context, _) => SceneBackground(
        spec: SceneLibrary.instance.backgroundFor(
          itemId,
          kind,
          choice: CalmVisualsSetting.instance.choiceFor(itemId),
        ),
        intensity: intensity,
        swell: swell,
      ),
    );
    if (child == null) return scene;
    return ColoredBox(
      color: context.brand.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: scene),
          child!,
        ],
      ),
    );
  }
}
