import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
import 'practice/practice_repository.dart';
import 'sounds/sound_player.dart';
import 'splash_screen.dart';
import 'supabase_config.dart';

/// Sentry project `techgetafrica-e6/flutter`. A DSN only lets a client *send*
/// events — it reads nothing — so like the Supabase publishable key it is a
/// public identifier and ships in the binary.
const _sentryDsn =
    'https://cbe3a2de2666c01da0c597028501567c@o4512097235238912.ingest.us.sentry.io/4512097243430912';

Future<void> main() async {
  // Sentry wraps the whole launch: it installs the framework and platform
  // error hooks before anything else runs, so a crash during start-up is
  // reported too, then hands over to [_start].
  await SentryFlutter.init(_configureSentry, appRunner: _start);
}

void _configureSentry(SentryFlutterOptions options) {
  options.dsn = _sentryDsn;
  options.environment = kReleaseMode ? 'production' : 'development';
  // This is a mental-health app: an event carries the stack trace, device
  // model, OS and app version — enough to fix a crash — and never the IP
  // address, request headers or a screenshot, which could show what someone
  // was writing or which therapist they talked to.
  options.sendDefaultPii = false;
  options.attachScreenshot = false;
  // Performance tracing: every transaction while developing, one in five in
  // production, which is plenty to spot a slow screen without burning quota.
  // Screen transactions come from the SentryNavigatorObserver on MaterialApp.
  options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
  // Session Replay. A replay of this app is a recording of someone's journal
  // and therapy, so production keeps only the replay of a session that hit an
  // error, and every piece of text and every image is masked — the SDK
  // default, restated so nobody flips it without reading this. Development
  // records every session so the feature can be checked.
  options.replay.sessionSampleRate = kReleaseMode ? 0.0 : 1.0;
  options.replay.onErrorSampleRate = 1.0;
  options.privacy.maskAllText = true;
  options.privacy.maskAllImages = true;
  // Logs: the app's own diagnostic lines, see [_forwardDebugPrintsToSentry].
  options.enableLogs = true;
}

/// Sends the app's `debugPrint` lines to Sentry Logs in release builds, where
/// nobody can read the console. Every one of them is a failure description
/// ("RevenueCat offerings failed: …", "Joining the session failed: …") and
/// most sit in catch blocks that otherwise swallow the error, so this is what
/// makes those failures visible in the field. They never carry user content.
void _forwardDebugPrintsToSentry() {
  if (!kReleaseMode) return;
  final console = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    console(message, wrapWidth: wrapWidth);
    if (message != null && message.isNotEmpty) {
      Sentry.logger.warn(message);
    }
  };
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  _forwardDebugPrintsToSentry();

  // A widget that throws while building shows a plain grey rectangle in
  // release — no explanation, no way out. Give people something they can
  // act on instead. Sentry already has the exception by this point, through
  // FlutterError.onError, so it only needs logging here.
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
  } catch (error, stackTrace) {
    debugPrint('Background audio unavailable, playing in foreground: $error');
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }
  await PurchasesService.instance.init();
  await initOnboardingFlags();
  await _initSessionNotifications();
  runApp(SentryWidget(child: const MyApp()));
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
  } catch (error, stackTrace) {
    debugPrint('Session notifications unavailable: $error');
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        // Practice finished offline, or as the app was killed, is written
        // once there's a signed-in user to write it for.
        case AuthChangeEvent.initialSession || AuthChangeEvent.signedIn:
          unawaited(PracticeRepository().flushPending());
        // A password-recovery email deep-links back into the app and signs
        // the user in; from there they still need to choose the new password.
        case AuthChangeEvent.passwordRecovery:
          if (!NewPasswordScreen.isShowing) {
            appNavigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
            );
          }
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
    }, onError: (Object error) {
      // A refresh that failed for network reasons arrives here with the
      // session intact, and the client retries it on its next tick. Only a
      // refresh token the server rejects ends the session, and that comes
      // through as a signedOut event above. Treating every stream error as
      // a sign-out used to log people out on an hourly refresh over bad
      // Wi-Fi. Nothing to do here but note it.
      debugPrint('Auth stream error (session kept): $error');
    });
  }

  void _toLogin() {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Coming back to the app is the other natural moment to catch up.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PracticeRepository().flushPending());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      // Gives Sentry the app-start transaction and one per named route; the
      // app's routes are unnamed today, so screens show up once they get a
      // RouteSettings name.
      navigatorObservers: [SentryNavigatorObserver(), appRoutes],
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
