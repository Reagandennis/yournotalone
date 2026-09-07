import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import '../home/home_shell.dart';

/// Shared layout for the onboarding screens: optional step dots up top,
/// scrollable content, and a pinned button area at the bottom.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.dismissible = false,
    this.step,
    required this.children,
    this.bottom,
  });

  /// 0-based step for the progress dots; null hides them.
  final int? step;
  final List<Widget> children;
  final Widget? bottom;

  /// Shows a close button. Onboarding proper has no way out by design, but
  /// the paywall is also reached from Settings and from upgrade sheets —
  /// and a screen you can only leave by picking "Free" is a trap.
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                if (dismissible)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 12),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: Brand.textMuted,
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                if (step != null)
                  Padding(
                    padding: EdgeInsets.only(top: dismissible ? 0 : 18),
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

/// SharedPreferences mirror of `onboarding_complete`.
///
/// The authoritative copy lives in the user's auth metadata, but that write
/// can fail — and when it did, the user was sent back through onboarding
/// *and the paywall* on next launch, which is a terrible thing to do to
/// someone who just paid. This local flag is the safety net.
///
/// Keyed per user id, because two people can share a phone and the second
/// one still deserves their own first run.
SharedPreferences? _prefs;

String _onboardingKey(String userId) => 'onboarding_complete_$userId';

/// Loads the local flags once at startup so the check can stay synchronous
/// (every caller of [postAuthDestination] builds a widget).
Future<void> initOnboardingFlags() async {
  try {
    _prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Without it we simply fall back to the auth metadata.
  }
}

bool onboardingDoneLocally(String userId) =>
    _prefs?.getBool(_onboardingKey(userId)) ?? false;

/// Saves onboarding answers without navigating anywhere.
Future<void> saveOnboardingAnswers(Map<String, dynamic> data) async {
  try {
    await Supabase.instance.client.auth.updateUser(UserAttributes(data: data));
  } catch (_) {
    // Answers are a nice-to-have; never block on them.
  }
}

/// Marks onboarding finished (plus any answers worth keeping) on the
/// user's profile, then hands over to the home screen.
Future<void> completeOnboarding(
  BuildContext context,
  Map<String, dynamic> data,
) async {
  // Local first, so the flag survives even if the network write doesn't.
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null) {
    try {
      await (_prefs ??= await SharedPreferences.getInstance())
          .setBool(_onboardingKey(userId), true);
    } catch (_) {
      // Best effort.
    }
  }
  try {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'onboarding_complete': true, ...data}),
    );
  } catch (_) {
    // Covered by the local flag above.
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeShell()),
    (route) => false,
  );
}
