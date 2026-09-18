import 'package:flutter/material.dart';

/// Animated splash screen: the four pillars rise into place one after
/// another, then the wordmark fades in beneath them.
///
/// The layer images in assets/splash/ all share the same canvas size and
/// were cut from "white logo v1.png", so stacking them reproduces the logo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  /// The screen to show once the intro finishes.
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _layerAspect = 780 / 937; // canvas size of the layer images

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 600), _goToNext);
      }
    });
  }

  void _goToNext() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final own = ModalRoute.of(context)!;
    // Already taken off the stack (an expired session sent the app to
    // login while the intro played): nothing left to hand over to.
    if (!own.isActive) return;
    final next = PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => widget.next,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (own.isCurrent) {
      navigator.pushReplacement(next);
    } else {
      // Something was pushed over the splash while it played — a
      // password-reset link opening the app does this. pushReplacement
      // would replace *that* screen, dropping the person into Home with
      // their old password. Swap out the splash underneath instead.
      navigator.replace(oldRoute: own, newRoute: next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A layer that rises from [offset] pixels below while fading in,
  /// active during [begin]..[end] of the controller's timeline.
  Widget _risingLayer(
    String asset, {
    required double begin,
    required double end,
    double offset = 90,
  }) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - curved.value)),
          child: child,
        ),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FractionallySizedBox(
          widthFactor: 0.72,
          child: AspectRatio(
            aspectRatio: _layerAspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _risingLayer('assets/splash/pillar_red.png',
                    begin: 0.00, end: 0.38),
                _risingLayer('assets/splash/pillar_blue.png',
                    begin: 0.12, end: 0.50),
                _risingLayer('assets/splash/pillar_black.png',
                    begin: 0.24, end: 0.62),
                _risingLayer('assets/splash/pillar_yellow.png',
                    begin: 0.36, end: 0.74),
                _risingLayer('assets/splash/title.png',
                    begin: 0.62, end: 0.86, offset: 30),
                _risingLayer('assets/splash/subtitle.png',
                    begin: 0.76, end: 1.00, offset: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
