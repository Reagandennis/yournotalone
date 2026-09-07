import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_shell.dart';
import '../onboarding/onboarding_ui.dart';
import '../onboarding/welcome_screen.dart';
import 'login_screen.dart';

/// Where a signed-in user should land: onboarding on their first time,
/// home ever after.
Widget postAuthDestination() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const LoginScreen();
  // Either source counts: the metadata write can fail, and re-running
  // onboarding (and the paywall) for someone who already finished is worse
  // than trusting a local flag.
  final done = user.userMetadata?['onboarding_complete'] == true ||
      onboardingDoneLocally(user.id);
  if (done) return const HomeShell();
  return const WelcomeScreen();
}

/// Decides where the app goes after the splash: into the signed-in flow
/// when a session was restored from a previous run, otherwise to login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) return postAuthDestination();
    return const LoginScreen();
  }
}
