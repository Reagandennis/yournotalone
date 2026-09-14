import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app_navigation.dart';
import 'auth/auth_gate.dart';
import 'auth/login_screen.dart';
import 'auth/new_password_screen.dart';
import 'billing/purchases_service.dart';
import 'brand.dart';
import 'home/home_shell.dart';
import 'notifications/local_notifications.dart';
import 'notifications/session_notifications.dart';
import 'onboarding/onboarding_ui.dart';
import 'sounds/sound_player.dart';
import 'splash_screen.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A widget that throws while building shows a plain grey rectangle in
  // release — no explanation, no way out. Give people something they can
  // act on instead, and keep the error in the log for a bug report.
  ErrorWidget.builder = (details) {
    debugPrint('Widget build failed: ${details.exception}');
    return const _SomethingWentWrong();
  };
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
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
  await _initSessionNotifications();
  runApp(const MyApp());
}

/// Notification taps open the session they're about, and on Android a
/// background task checks for session news. Never fatal.
Future<void> _initSessionNotifications() async {
  try {
    await LocalNotifications.ensureInitialized();
    LocalNotifications.onOpen = openSessionScreen;
    if (Platform.isAndroid) {
      await Workmanager().initialize(sessionNotificationsCallback);
    }
  } catch (error) {
    debugPrint('Session notifications unavailable: $error');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
          );
        // Without this, an expired or revoked session leaves the app sitting
        // in HomeShell with no user: every repository throws "Not signed in",
        // every screen reports it as a connection problem, and "Try again"
        // can never succeed. Send them somewhere they can actually recover.
        case AuthChangeEvent.signedOut:
          unawaited(SessionNotifications.instance.stop());
          _toLogin();
        default:
          break;
      }
      // A failed token refresh arrives as a stream error, not an event.
    }, onError: (_) => _toLogin());
  }

  void _toLogin() {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
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
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Δεν είσαι μόνος',
      theme: buildAppTheme(),
      home: const SplashScreen(next: AuthGate()),
    );
  }
}

/// Shown in place of a widget that failed to build.
class _SomethingWentWrong extends StatelessWidget {
  const _SomethingWentWrong();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 40, color: Brand.textMuted),
              const SizedBox(height: 14),
              const Text(
                'Something went wrong here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Go back and try again — nothing you saved is affected.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Brand.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
