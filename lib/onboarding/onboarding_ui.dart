import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import '../home/home_shell.dart';

/// Shared layout for the onboarding screens: optional step dots up top,
/// scrollable content, and a pinned button area at the bottom.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.step,
    required this.children,
    this.bottom,
  });

  /// 0-based step for the progress dots; null hides them.
  final int? step;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                if (step != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: OnboardingDots(step: step!),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                    children: children,
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-step progress indicator; the active dot stretches into a pill
/// tinted with a pillar colour.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({super.key, required this.step});

  final int step;

  static const _accents = [Brand.red, Brand.blue, Brand.yellow];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == step ? 26 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == step ? _accents[i] : Brand.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}

/// Marks onboarding finished (plus any answers worth keeping) on the
/// user's profile, then hands over to the home screen.
Future<void> completeOnboarding(
  BuildContext context,
  Map<String, dynamic> data,
) async {
  try {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'onboarding_complete': true, ...data}),
    );
  } catch (_) {
    // Not fatal — worst case they see onboarding again next launch.
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeShell()),
    (route) => false,
  );
}
