import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';
import 'auth/login_screen.dart';
import 'auth/new_password_screen.dart';
import 'billing/purchases_service.dart';
import 'brand.dart';
import 'onboarding/onboarding_ui.dart';
import 'sounds/sound_player.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zpcfavemnvfhqaxqhmri.supabase.co',
    publishableKey: 'sb_publishable_yKBVrkk13Sm5hMZtrerdiw_uTrhlNd9',
  );
  // Enables the media notification and lock-screen controls, so a sleep
  // sound keeps playing when the screen goes off.
  //
  // Never fatal: a hot restart after adding the plugin, or a platform with
  // no implementation, throws MissingPluginException here — and the app
  // failing to launch over a media session would be far worse than losing
  // background playback.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.techgetafrica.yournotalone.audio',
      androidNotificationChannelName: 'Wellbeing sounds',
      androidNotificationOngoing: true,
    );
    backgroundAudioReady = true;
  } catch (error) {
    debugPrint('Background audio unavailable, playing in foreground: $error');
  }
  await PurchasesService.instance.init();
  await initOnboardingFlags();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        // A password-recovery email deep-links back into the app and signs
        // the user in; from there they still need to choose the new password.
        case AuthChangeEvent.passwordRecovery:
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
          );
        // Without this, an expired or revoked session leaves the app sitting
        // in HomeShell with no user: every repository throws "Not signed in",
        // every screen reports it as a connection problem, and "Try again"
        // can never succeed. Send them somewhere they can actually recover.
        case AuthChangeEvent.signedOut:
          _toLogin();
        default:
          break;
      }
      // A failed token refresh arrives as a stream error, not an event.
    }, onError: (_) => _toLogin());
  }

  void _toLogin() {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Δεν είσαι μόνος',
      theme: buildAppTheme(),
      home: const SplashScreen(next: AuthGate()),
    );
  }
}
