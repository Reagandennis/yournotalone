import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/auth/login_screen.dart';
import 'package:yournotalone/auth/signup_screen.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/brand_layout.dart';
import 'package:yournotalone/care/care_dashboard_screen.dart';
import 'package:yournotalone/care/care_repository.dart';
import 'package:yournotalone/care/match_screen.dart';
import 'package:yournotalone/care/request_detail_screen.dart';
import 'package:yournotalone/care/therapist_editor_screen.dart';
import 'package:yournotalone/care/therapist_sessions_screen.dart';
import 'package:yournotalone/cbt/cbt_screen.dart';
import 'package:yournotalone/cbt/thought_record_screen.dart';
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
import 'package:yournotalone/splash_screen.dart';
import 'package:yournotalone/stress/sigh_screen.dart';
import 'package:yournotalone/support/crisis_screen.dart';
import 'package:yournotalone/support/faq_screen.dart';
import 'package:yournotalone/therapy/call_screen.dart';
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

// Long names and notes on purpose: they are what overflows.
const _longTherapist = TherapistProfile(
  id: 't',
  fullName: 'Dr. Wanjiku Kamau-Otieno',
  title: 'Counselling psychologist, addiction and recovery specialist',
  specialties: ['Grief & loss', 'Addiction & recovery'],
  ratingAverage: 4.8,
  ratingCount: 12,
);

class _BookedTherapy extends TherapyRepository {
  @override
  Future<List<TherapyRequest>> fetchRequests() async => [
        TherapyRequest(
          id: 'b',
          topic: 'Addiction & recovery',
          availability: const ['Weekday evenings'],
          note: null,
          status: 'confirmed',
          isFreeSession: false,
          scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
          createdAt: DateTime.now(),
          therapistId: 't',
          priceCents: 2000,
          paymentStatus: 'unpaid',
        ),
        TherapyRequest(
          id: 'c',
          topic: 'Relationships',
          availability: const [],
          note: null,
          status: 'completed',
          isFreeSession: true,
          scheduledAt: DateTime.now().subtract(const Duration(days: 9)),
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          therapistId: 't',
        ),
      ];

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
          Iterable<String> ids) async =>
      const {'t': _longTherapist};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};
}

final _pendingItem = AdminTherapyRequest(
  request: TherapyRequest(
    id: 'p',
    topic: 'Grief & loss',
    availability: const ['Weekday mornings', 'Weekends'],
    note: 'I lost my father in June and I haven\'t slept properly since.',
    status: 'pending',
    isFreeSession: false,
    scheduledAt: null,
    createdAt: DateTime(2026, 9, 1),
    priceCents: 2000,
    paymentStatus: 'unpaid',
  ),
  clientId: 'c',
  clientName: 'Nikolaos Papadopoulos-Karamanlis',
  clientEmail: 'nikolaos.papadopoulos-karamanlis@example.com',
);

const _careTherapist = AdminTherapist(
  profile: _longTherapist,
  email: 'wanjiku.kamau-otieno@example.com',
  hasAccount: false,
  upcomingSessions: 3,
  completedSessions: 18,
);

class _Care extends CareRepository {
  @override
  Future<List<AdminTherapyRequest>> listRequests() async => [_pendingItem];

  @override
  Future<List<AdminTherapist>> listTherapists() async => const [_careTherapist];

  @override
  Future<List<TherapistSession>> listMySessions() async => [
        TherapistSession(
          id: 's',
          status: 'confirmed',
          topic: 'Grief & loss',
          availability: const [],
          note: _pendingItem.request.note,
          scheduledAt: DateTime.now().subtract(const Duration(minutes: 5)),
          durationMinutes: 50,
          paymentStatus: 'unpaid',
          isFreeSession: false,
          clientFirstName: 'Nikolaos',
        ),
      ];
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
    'TherapyScreen (booked)': () => TherapyScreen(repository: _BookedTherapy()),
    'CallScreen': () => CallScreen(
          counterpartName: _longTherapist.fullName,
          connect: () async => throw const SessionAccessException('too_early'),
        ),
    'CareDashboardScreen': () => CareDashboardScreen(repository: _Care()),
    'RequestDetailScreen': () =>
        RequestDetailScreen(item: _pendingItem, repository: _Care()),
    'MatchScreen': () => MatchScreen(item: _pendingItem, repository: _Care()),
    'TherapistEditorScreen': () => TherapistEditorScreen(
          therapist: _careTherapist,
          repository: _Care(),
        ),
    'TherapistSessionsScreen': () =>
        TherapistSessionsScreen(repository: _Care()),
    'CrisisScreen': () => const CrisisScreen(),
    'FaqScreen': () => const FaqScreen(),
    'LegalScreen': () => LegalScreen(doc: privacyPolicy),
    'RemindersScreen': () => const RemindersScreen(),
    'WelcomeScreen': () => const WelcomeScreen(),
    'FeaturesScreen': () => const FeaturesScreen(),
    'CheckinScreen': () => const CheckinScreen(),
    'PaywallScreen': () =>
        const PaywallScreen(checkin: 'steady', fromOnboarding: true),
    'LoginScreen': () => const LoginScreen(),
    'SignupScreen': () => const SignupScreen(),
    'CbtScreen': () => const CbtScreen(),
    'ThoughtRecordScreen': () => const ThoughtRecordScreen(),
    'SighScreen': () => const SighScreen(),
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

  // Dark mode draws every colour through the theme, so a screen or painter
  // still holding a light-only value fails to build here.
  testWidgets('every screen builds in dark mode', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final broken = <String>[];
    for (final entry in screens.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          home: entry.value(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final error = tester.takeException();
      if (error != null) {
        broken.add('${entry.key}: ${error.toString().split('\n').first}');
      }
    }

    expect(broken, isEmpty,
        reason: 'Dark mode failures:\n${broken.join('\n')}');
  });

  // ---------------------------------------------------------------- iPad --

  // The app ships for iPad (TARGETED_DEVICE_FAMILY 1,2, every orientation),
  // and App Review tries it there. Phone layouts stretched to 1366 points
  // look broken, so content keeps a phone-like column on a tablet.

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget screen, {
    double textScale = 1,
  }) async {
    // A real iPad Pro 13" is 2048x2732 physical pixels at 2x.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 2,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Widths of every on-screen vertical scroll view: where the reading
  /// content lives.
  List<double> readingWidths(WidgetTester tester) => [
        for (final element in find.byType(Scrollable).evaluate())
          if (axisDirectionToAxis(
                  (element.widget as Scrollable).axisDirection) ==
              Axis.vertical)
            (element.renderObject! as RenderBox).size.width,
      ];

  const tablets = [
    ('iPad Pro 13 portrait', Size(1032, 1376)),
    ('iPad Pro 13 landscape', Size(1376, 1032)),
    ('iPad Pro 12.9 portrait', Size(1024, 1366)),
    ('iPad Pro 12.9 landscape', Size(1366, 1024)),
    ('iPad Air portrait', Size(820, 1180)),
    ('iPad mini landscape', Size(1133, 744)),
    // Split View and Slide Over hand the app a narrow, very tall window.
    ('Split View half', Size(683, 1024)),
    ('Split View third', Size(375, 1024)),
    ('Slide Over', Size(320, 1024)),
  ];

  for (final (label, size) in tablets) {
    testWidgets('every screen lays out on $label', (tester) async {
      addTearDown(tester.view.reset);
      final broken = <String>[];
      for (final entry in screens.entries) {
        await pumpAt(tester, size, entry.value());
        final error = tester.takeException();
        if (error != null) {
          broken.add('${entry.key}: ${error.toString().split('\n').first}');
        }
      }
      expect(broken, isEmpty,
          reason: 'Layout failures on $label:\n${broken.join('\n')}');
    });
  }

  const stillFullWidth = {
    // Pumped bare here; in the app they sit inside HomeShell, whose
    // column is checked as 'HomeShell'.
    'HomeTab', 'ExploreTab', 'SettingsTab',
  };

  for (final (label, size) in [
    ('iPad portrait', const Size(1024, 1366)),
    ('iPad landscape', const Size(1366, 1024)),
  ]) {
    testWidgets('reading content stays a column on $label', (tester) async {
      addTearDown(tester.view.reset);
      final tooWide = <String>[];
      for (final entry in screens.entries) {
        if (stillFullWidth.contains(entry.key)) continue;
        await pumpAt(tester, size, entry.value());
        tester.takeException();
        final widths = readingWidths(tester);
        final widest = widths.isEmpty ? 0.0 : widths.reduce(math.max);
        if (widest > kReadableMaxWidth) {
          tooWide.add('${entry.key}: ${widest.toStringAsFixed(0)}pt');
        }
      }
      expect(tooWide, isEmpty,
          reason: 'Content wider than ${kReadableMaxWidth}pt on $label:\n'
              '${tooWide.join('\n')}');
    });
  }

  testWidgets('phones keep the full width the tablet cap never touches',
      (tester) async {
    addTearDown(tester.view.reset);
    const phone = Size(430, 932);
    for (final name in [
      'CbtScreen',
      'ThoughtRecordScreen',
      'CareDashboardScreen',
      'MatchScreen',
      'RequestDetailScreen',
      'TherapistEditorScreen',
      'TherapistSessionsScreen',
    ]) {
      await pumpAt(tester, phone, screens[name]!());
      expect(tester.takeException(), isNull, reason: name);
      // The page itself scrolls edge to edge, as before; anything
      // narrower is a scroll view inside it (a text field, a card).
      expect(readingWidths(tester).reduce(math.max), phone.width,
          reason: name);
    }
  });

  testWidgets('tab bar spans a phone, and groups its tabs on an iPad',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, const Size(390, 844), const HomeShell());
    expect(tester.getSize(find.byType(NavigationBar)).width, 390);

    await pumpAt(tester, const Size(1366, 1024), const HomeShell());
    expect(tester.getSize(find.byType(NavigationBar)).width, 520);
    // The bar's colour still runs edge to edge.
    final bar = find.ancestor(
      of: find.byType(NavigationBar),
      matching: find.byType(Container),
    );
    expect(tester.getSize(bar.first).width, 1366);
  });

  testWidgets('splash logo: phone size unchanged, capped on iPad',
      (tester) async {
    addTearDown(tester.view.reset);
    Future<double> logoWidth(Size size) async {
      await pumpAt(
        tester,
        size,
        const SplashScreen(next: Scaffold(body: Text('NEXT'))),
      );
      return tester.getSize(find.byType(AspectRatio).first).width;
    }

    expect(await logoWidth(const Size(390, 844)), closeTo(390 * 0.72, 0.01));
    expect(await logoWidth(const Size(1024, 1366)), 360);
    final landscape = await logoWidth(const Size(1366, 1024));
    expect(landscape, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
    // Let the splash finish so no timers outlive the test.
    for (final ms in [3000, 300, 500, 500]) {
      await tester.pump(Duration(milliseconds: ms));
    }
  });

  testWidgets('sheets and dialogs stay phone-sized on a landscape iPad',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(
      tester,
      const Size(1366, 1024),
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                    height: 200,
                    child: Text('SHEET'),
                  ),
                ),
                child: const Text('open sheet'),
              ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Leave the session?'),
                    content: Text('A long explanation. ' * 30),
                  ),
                ),
                child: const Text('open dialog'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final sheet = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Material),
    );
    expect(tester.getSize(sheet.first).width, lessThanOrEqualTo(640));
    Navigator.of(tester.element(find.text('SHEET'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    final dialog = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Material),
    );
    expect(tester.getSize(dialog.first).width, lessThanOrEqualTo(560));
    expect(tester.takeException(), isNull);
  });
}
