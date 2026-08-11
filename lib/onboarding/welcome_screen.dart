import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import 'features_screen.dart';
import 'onboarding_ui.dart';

/// First onboarding screen: greets the user by name and tells the story
/// behind the app's Greek name, with the same staggered motion language
/// as the splash.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _firstName {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final fullName = (meta?['full_name'] as String?)?.trim();
    if (fullName == null || fullName.isEmpty) return 'friend';
    return fullName.split(RegExp(r'\s+')).first;
  }

  /// Fades [child] in (with a gentle upward drift) during the
  /// [begin]..[end] slice of the timeline.
  Widget _reveal({
    required Widget child,
    required double begin,
    required double end,
    double drift = 24,
  }) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, drift * (1 - curved.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 0,
      bottom: _reveal(
        begin: 0.85,
        end: 1.0,
        drift: 0,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FeaturesScreen()),
          ),
          child: const Text('Continue'),
        ),
      ),
      children: [
        const SizedBox(height: 12),
        _reveal(
          begin: 0.0,
          end: 0.30,
          drift: 12,
          child: Center(
            child: Image.asset('assets/brand/pillars.png', height: 150),
          ),
        ),
        const SizedBox(height: 30),
        _reveal(
          begin: 0.20,
          end: 0.45,
          child: Text(
            'Welcome, $_firstName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _reveal(
          begin: 0.38,
          end: 0.56,
          child: const Center(child: PillarStripe()),
        ),
        const SizedBox(height: 26),
        _reveal(
          begin: 0.50,
          end: 0.74,
          child: const Text(
            'Δεν είσαι μόνος',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Brand.ink,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _reveal(
          begin: 0.66,
          end: 0.92,
          child: const Text(
            'It\'s Greek for "you\'re not alone" — the promise this app is '
            'built on. Like the four pillars in our logo, support stands '
            'strongest side by side. Whatever you\'re carrying, from today '
            'you don\'t carry it by yourself.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Brand.textMuted,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
