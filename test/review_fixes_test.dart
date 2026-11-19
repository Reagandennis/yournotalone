// Fixes from the 19 November 2026 review that don't belong to one screen's
// tests: what's kept on a shared phone, sign-in messages, the crisis
// country, practice totals, saved items, the database's refusals in the
// app's words, and the free trial for someone who has had it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/account/local_data.dart';
import 'package:yournotalone/auth/auth_ui.dart';
import 'package:yournotalone/auth/login_screen.dart';
import 'package:yournotalone/billing/paywall_copy.dart';
import 'package:yournotalone/billing/pricing_copy.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/saved_store.dart';
import 'package:yournotalone/l10n/app_localizations_en.dart';
import 'package:yournotalone/practice/pending_practice.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/support/crisis_resources.dart';
import 'package:yournotalone/support/crisis_screen.dart';
import 'package:yournotalone/support/heavy_day_sheet.dart';
import 'package:yournotalone/therapy/server_messages.dart';

import 'fake_packages.dart';

class _Remote implements SavedItemsRemote {
  final saved = <String>[];
  @override
  Future<List<String>> fetch() async => [...saved];
  @override
  Future<void> add(List<String> ids) async => saved.insertAll(0, ids);
  @override
  Future<void> remove(List<String> ids) async => saved.removeWhere(ids.contains);
}

void main() {
  final l10n = AppLocalizationsEn();

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

  group('a shared phone', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'cbt.worries': '["exam results"]',
        'sleep.diary': '[{"night":"2026-11-18"}]',
        'practice.feelings': '[]',
        'reminder_checkin_enabled': true,
        'appearance': 'dark',
        'language': 'en',
        'crisis.country': 'KE',
      });
      prefs = await SharedPreferences.getInstance();
      LocalData.instance.debugUse(prefs);
    });

    test('the first person to sign in keeps what was on the phone', () {
      expect(LocalData.instance.signedIn('ana'), isFalse);
      expect(prefs.getString('cbt.worries'), '["exam results"]');
    });

    test('the next person starts with their own, and the first gets theirs '
        'back', () {
      LocalData.instance.signedIn('ana');
      LocalData.instance.signedOut();
      expect(prefs.getString('cbt.worries'), isNull);
      expect(prefs.getBool('reminder_checkin_enabled'), isNull);
      // The phone's own settings stay.
      expect(prefs.getString('appearance'), 'dark');
      expect(prefs.getString('crisis.country'), 'KE');

      expect(LocalData.instance.signedIn('ben'), isTrue);
      expect(prefs.getString('cbt.worries'), isNull);
      expect(prefs.getString('sleep.diary'), isNull);
      prefs.setString('cbt.worries', '["ben\'s worry"]');
      LocalData.instance.signedOut();

      expect(LocalData.instance.signedIn('ana'), isTrue);
      expect(prefs.getString('cbt.worries'), '["exam results"]');
      expect(prefs.getBool('reminder_checkin_enabled'), isTrue);
    });

    test('someone else signing in without a sign-out still gets their own',
        () {
      LocalData.instance.signedIn('ana');
      expect(LocalData.instance.signedIn('ben'), isTrue);
      expect(prefs.getString('cbt.worries'), isNull);
      LocalData.instance.signedIn('ana');
      expect(prefs.getString('cbt.worries'), '["exam results"]');
    });

    test('a deleted account leaves nothing behind', () {
      LocalData.instance.signedIn('ana');
      LocalData.instance.forget('ana');
      expect(prefs.getString('cbt.worries'), isNull);
      expect(prefs.getKeys().where((k) => k.contains('ana')), isEmpty);
      expect(prefs.getString('appearance'), 'dark');
    });

    test('only personal keys move', () {
      for (final key in [
        'cbt.plan.2026-11-19',
        'sleep.tomorrow.2026-11-19',
        'stress.recharge',
        'discover.recent_searches',
        'courses.progress',
        'goals',
        'rhythm.weekly_goal',
        'reminder_pledge_hour',
      ]) {
        expect(LocalData.isPersonal(key), isTrue, reason: key);
      }
      for (final key in [
        'appearance',
        'language',
        'crisis.country',
        'media.downloads',
        'catalog.snapshot',
        'discover.saved',
        'billing.latestSeen',
        'onboarding_complete',
      ]) {
        expect(LocalData.isPersonal(key), isFalse, reason: key);
      }
    });
  });

  group('sign-in messages', () {
    test('say what went wrong in plain words', () {
      expect(
        authErrorMessage(
          l10n,
          const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'),
        ),
        l10n.authErrorInvalidCredentials,
      );
      expect(
        authErrorMessage(l10n, const AuthApiException('Email not confirmed', statusCode: '400')),
        l10n.authErrorEmailNotConfirmed,
      );
      expect(
        authErrorMessage(l10n, const AuthException('User already registered', code: 'user_already_exists')),
        l10n.authErrorEmailTaken,
      );
      expect(
        authErrorMessage(l10n, const AuthApiException('Too many', statusCode: '429', code: 'over_request_rate_limit')),
        l10n.authErrorTooManyTries,
      );
    });

    test('never show a raw network error', () {
      expect(authErrorMessage(l10n, const SocketException('Failed host lookup')), l10n.authErrorOffline);
      expect(authErrorMessage(l10n, http.ClientException('Connection closed')), l10n.authErrorOffline);
      expect(authErrorMessage(l10n, AuthRetryableFetchException(message: 'ClientException with SocketException')), l10n.authErrorOffline);
      expect(authErrorMessage(l10n, const AuthApiException('boom', statusCode: '500')), l10n.authErrorGeneric);
    });

    testWidgets('the login screen links to the crisis numbers, without '
        'booking', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const LoginScreen()));
      await tester.pump();
      final link = find.byType(CrisisFooter);
      await tester.scrollUntilVisible(link, 200,
          scrollable: find.byType(Scrollable).first);
      expect(link, findsOneWidget);
      // Clear of the sign-up bar pinned at the bottom.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(CrisisScreen), findsOneWidget);
      expect(find.text('Book a session'), findsNothing);
    });
  });

  group('the crisis country', () {
    tearDown(() {
      CrisisCountrySetting.instance.debugDetected = null;
      CrisisCountrySetting.instance.value = null;
    });

    test('where the phone is beats its language', () {
      CrisisCountrySetting.instance.debugDetected = 'KE';
      expect(crisisCountry(const [Locale('en', 'US')], false), 'KE');
      CrisisCountrySetting.instance.debugDetected = null;
      expect(crisisCountry(const [Locale('en', 'US')], false), 'US');
    });

    test('a country picked on the crisis screen beats both', () {
      CrisisCountrySetting.instance.debugDetected = 'KE';
      CrisisCountrySetting.instance.value = 'GB';
      expect(crisisCountry(const [Locale('en', 'US')], false), 'GB');
    });

    test('only numbers the review confirmed ship', () {
      final kenya = crisisRegionFor('KE', drafts: false);
      expect(kenya.lines.map((l) => l.phone), isNot(contains('+254 718 227 440')));
      final greece = crisisRegionFor('GR', drafts: false);
      expect(greece.lines.map((l) => l.phone), isNot(contains('10306')));
      expect(greece.lines.map((l) => l.phone), contains('1018'));
    });

    testWidgets('the heavy-day sheet says whose numbers they are', (tester) async {
      CrisisCountrySetting.instance.debugDetected = 'KE';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showHeavyDaySheet(context),
              child: const Text('Awful'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Awful'));
      await tester.pumpAndSettle();
      expect(find.text('Numbers for Kenya'), findsOneWidget);
    });
  });

  group('practice totals', () {
    test('count every session, plus what is still on the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final pending = PendingPracticeStore();
      await pending.add(PendingPracticeSession(
        id: 'p1',
        userId: 'u1',
        kind: PracticeKind.meditation,
        slug: 'body-scan',
        title: 'Body scan',
        minutes: 10,
        completedAt: DateTime.now(),
      ));
      final repo = PracticeRepository(
        currentUserId: () => 'u1',
        pending: pending,
        fetchRows: (_, __) async => [
          {
            'kind': 'meditation',
            'slug': 'calm',
            'title': 'Calm',
            'minutes': 5,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        fetchTotals: () async => (300, 2400.0),
      );
      final summary = await repo.fetchSummary();
      expect(summary.sessions, 301);
      expect(summary.totalMinutes, 2410);
      expect(summary.dayStreak, 1);
    });

    test('without the server\'s totals, the fetched days still add up', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PracticeRepository(
        currentUserId: () => 'u1',
        pending: PendingPracticeStore(),
        fetchRows: (_, __) async => [
          {
            'kind': 'meditation',
            'slug': 'calm',
            'title': 'Calm',
            'minutes': 5,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      );
      expect((await repo.fetchSummary()).sessions, 1);
    });
  });

  test('a sync before saved items load doesn\'t wipe them', () async {
    final rain = builtInContentIndex.firstWhere((i) => i.title == 'Rainfall');
    SharedPreferences.setMockInitialValues({
      'discover.saved': [rain.id],
      'discover.saved.owner': 'u1',
      'discover.saved.pending': '{"${rain.id}":"add"}',
    });
    final remote = _Remote();
    final store = SavedStore.forTest(remote: remote, userId: () => 'u1');
    // The sign-in event syncs before Home asks for the list.
    await store.sync();
    expect(store.isSaved(rain), isTrue);
    expect(remote.saved, [rain.id], reason: 'the offline heart was sent');
  });

  test('the database\'s refusals in the app\'s words', () {
    PostgrestException refusal(String message) =>
        PostgrestException(message: message, code: 'P0001');
    expect(
      serverMessage(l10n, refusal('You already have a session on the way. Cancel it first if you need to change something.')),
      l10n.therapyServerOpenSession,
    );
    expect(
      serverMessage(l10n, refusal('Your country comes from where your phone is. If it’s wrong, reply to any of our emails.')),
      l10n.therapyServerCountryDetected,
    );
    expect(serverMessage(l10n, refusal('Something new')), 'Something new');
  });

  test('no free trial is promised to someone who has had it', () {
    final monthly = fakePackages().first;
    expect(trialDays(monthly), 7);
    expect(introOffer, l10n.billingIntroOffer);
    introIneligible.add(monthly.storeProduct.identifier);
    addTearDown(introIneligible.clear);
    expect(trialDays(monthly), isNull);
    expect(trialLabel(monthly, l10n), isNull);
    expect(introOffer, l10n.billingNoTrialOffer);
  });
}
