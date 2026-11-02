import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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

  String _firstName(AppLocalizations l10n) {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final fullName = (meta?['full_name'] as String?)?.trim();
    if (fullName == null || fullName.isEmpty) {
      return l10n.onboardingWelcomeFriend;
    }
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
    final c = context.brand;
    final l10n = context.l10n;
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
          child: Text(l10n.commonContinue),
        ),
      ),
      children: [
        const SizedBox(height: 12),
        _reveal(
          begin: 0.0,
          end: 0.30,
          drift: 12,
          child: Center(
            child: Image.asset(c.pillarsAsset, height: 150),
          ),
        ),
        const SizedBox(height: 30),
        _reveal(
          begin: 0.20,
          end: 0.45,
          child: Text(
            l10n.onboardingWelcomeTitle(_firstName(l10n)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: c.ink,
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
          child: Text(
            'yournotalone',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: c.ink,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _reveal(
          begin: 0.66,
          end: 0.92,
          child: Text(
            l10n.onboardingWelcomeStory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textMuted,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
