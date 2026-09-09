import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/explore_tab.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/home/home_tab.dart';
import 'package:yournotalone/home/mood_history_screen.dart';
import 'package:yournotalone/home/mood_repository.dart';
import 'package:yournotalone/home/settings_tab.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/journal/journal_screen.dart';
import 'package:yournotalone/legal/legal_content.dart';
import 'package:yournotalone/legal/legal_screen.dart';
import 'package:yournotalone/meditation/breathing_screen.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';
import 'package:yournotalone/meditation/meditations_screen.dart';
import 'package:yournotalone/onboarding/checkin_screen.dart';
import 'package:yournotalone/onboarding/features_screen.dart';
import 'package:yournotalone/onboarding/paywall_screen.dart';
import 'package:yournotalone/onboarding/welcome_screen.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/practice/practice_screen.dart';
import 'package:yournotalone/recovery/halt_screen.dart';
import 'package:yournotalone/recovery/insights_screen.dart';
import 'package:yournotalone/recovery/milestones_screen.dart';
import 'package:yournotalone/recovery/recovery_repository.dart';
import 'package:yournotalone/recovery/recovery_screen.dart';
import 'package:yournotalone/recovery/tape_forward_screen.dart';
import 'package:yournotalone/reminders/reminders_screen.dart';
import 'package:yournotalone/sounds/player_screen.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/sounds/sounds_screen.dart';
import 'package:yournotalone/support/crisis_screen.dart';
import 'package:yournotalone/support/faq_screen.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

/// Repositories that answer instantly with a little data, so every screen
/// renders its populated state — the state most likely to overflow.
class _Practice extends PracticeRepository {
  @override
  Future<List<PracticeSession>> fetchRecent({int days = 120}) async => [
        PracticeSession(
          kind: PracticeKind.meditation,
          slug: 'Body scan',
          title: 'Body scan',
          minutes: 12,
          completedAt: DateTime.now(),
        ),
      ];
}

class _Moods extends MoodRepository {
  @override
  Future<List<MoodEntry>> fetchHistory({int days = 90}) async =>
      [MoodEntry(date: DateTime.now(), index: 4)];
}

class _Recovery extends RecoveryRepository {
  @override
  Future<List<RecoveryHabit>> fetchHabits() async => [
        RecoveryHabit(
          id: 'h',
          name: 'Alcohol',
          dayOne: DateTime.now().subtract(const Duration(days: 9)),
          bestStreakDays: 0,
          pledgedToday: false,
        ),
      ];

  @override
  Future<List<CravingLog>> fetchCravings({int days = 90}) async => [
        CravingLog(
          id: 'c',
          intensity: 4,
          trigger: 'Social pressure',
          note: null,
          createdAt: DateTime.now(),
        ),
      ];
}

class _Therapy extends TherapyRepository {
  @override
  Future<List<TherapyRequest>> fetchRequests() async => const [];
}

/// Phones this has to fit, from the smallest still in use upward.
const _devices = [
  ('small 320x568', Size(320, 568), 1.0),
  ('budget 360x640', Size(360, 640), 1.0),
  ('common 390x844', Size(390, 844), 1.0),
  ('pixel 412x915', Size(412, 915), 1.0),
  ('max 430x932', Size(430, 932), 1.0),
  // Someone with larger system text on a small phone — the hardest case,
  // and the one real users actually hit.
  ('small + big text', Size(360, 640), 1.3),
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  final screens = <String, Widget Function()>{
    'HomeShell': () => const HomeShell(),
    'HomeTab': () => Scaffold(body: HomeTab(practice: _Practice())),
    'ExploreTab': () => const Scaffold(body: ExploreTab()),
    'SettingsTab': () => const Scaffold(body: SettingsTab()),
    'MeditationsScreen': () => const MeditationsScreen(),
    'MeditationScreen': () => MeditationScreen(
          meditation: meditations.firstWhere((m) => m.minutes == 15),
          practice: _Practice(),
        ),
    'BreathingScreen': () =>
        BreathingScreen(pattern: breathPatterns.first, practice: _Practice()),
    'SoundsScreen': () => const SoundsScreen(),
    'PlayerScreen': () => PlayerScreen(sound: soundsCatalog.first),
    'JournalHubScreen': () => const JournalHubScreen(),
    'JournalScreen': () => const JournalScreen(),
    'MoodHistoryScreen': () => MoodHistoryScreen(repository: _Moods()),
    'PracticeScreen': () => PracticeScreen(repository: _Practice()),
    'RecoveryScreen': () => const RecoveryScreen(),
    'MilestonesScreen': () => MilestonesScreen(repository: _Recovery()),
    'TriggerInsightsScreen': () =>
        TriggerInsightsScreen(repository: _Recovery()),
    'HaltScreen': () => const HaltScreen(),
    'TapeForwardScreen': () => const TapeForwardScreen(),
    'TherapyScreen': () => TherapyScreen(repository: _Therapy()),
    'CrisisScreen': () => const CrisisScreen(),
    'FaqScreen': () => const FaqScreen(),
    'LegalScreen': () => LegalScreen(doc: privacyPolicy),
    'RemindersScreen': () => const RemindersScreen(),
    'WelcomeScreen': () => const WelcomeScreen(),
    'FeaturesScreen': () => const FeaturesScreen(),
    'CheckinScreen': () => const CheckinScreen(),
    'PaywallScreen': () =>
        const PaywallScreen(checkin: 'steady', fromOnboarding: true),
  };

  for (final (label, size, textScale) in _devices) {
    testWidgets('every screen lays out on $label', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final broken = <String>[];
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: entry.value(),
            ),
          ),
        );
        // Not pumpAndSettle: session screens animate their backdrop
        // forever, so there is no settled state to wait for.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final error = tester.takeException();
        if (error != null) {
          broken.add('${entry.key}: ${error.toString().split('\n').first}');
        }
      }

      expect(broken, isEmpty,
          reason: 'Layout failures on $label:\n${broken.join('\n')}');
    });
  }
}
