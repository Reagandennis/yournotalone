import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/notifications/notification_permission.dart';
import 'package:yournotalone/onboarding/notifications_screen.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

/// A phone whose answers the test controls: whether notifications are on,
/// what the system prompt returns, and whether Settings was opened.
class _Phone {
  _Phone({required this.enabled, this.grants = true});

  bool enabled;
  final bool grants;
  var prompts = 0;
  var settingsOpened = 0;

  NotificationPermission get permission => NotificationPermission(
    isEnabled: () async => enabled,
    request: () async {
      prompts++;
      enabled = grants;
      return enabled;
    },
    openSettings: () async {
      settingsOpened++;
      // The person flips the switch while they're there.
      enabled = true;
    },
  );
}

final _now = DateTime(2026, 10, 1, 12);

TherapyRequest _request({String status = 'pending'}) => TherapyRequest(
  id: 'r1',
  topic: 'Anxiety & stress',
  availability: const ['Weekends'],
  note: null,
  status: status,
  isFreeSession: false,
  scheduledAt: status == 'confirmed' ? _now.add(const Duration(days: 2)) : null,
  createdAt: _now,
  submittedAt: _now,
  therapistId: status == 'confirmed' ? 't1' : null,
  priceCents: 2000,
  paymentStatus: 'paid',
);

class _FakeTherapy extends TherapyRepository {
  _FakeTherapy(this.requests);

  final List<TherapyRequest> requests;

  @override
  Future<List<TherapyRequest>> fetchRequests() async => requests;

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
    Iterable<String> ids,
  ) async => const {'t1': TherapistProfile(id: 't1', fullName: 'Tess Mwangi')};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};
}

Widget _wrap(Widget screen) =>
    MaterialApp(theme: buildAppTheme(), home: screen);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('status', () {
    test('never asked, then refused, then enabled', () async {
      final phone = _Phone(enabled: false, grants: false);
      expect(await phone.permission.status(), NotificationAccess.notAsked);
      expect(await phone.permission.request(), isFalse);
      // The ask is remembered, so a refusal reads as denied from now on.
      expect(await phone.permission.status(), NotificationAccess.denied);
      phone.enabled = true;
      expect(await phone.permission.status(), NotificationAccess.enabled);
    });

    test('the launch prompt fires once and only when never asked', () async {
      final phone = _Phone(enabled: false, grants: false);
      await phone.permission.promptIfNeverAsked();
      await phone.permission.promptIfNeverAsked();
      expect(phone.prompts, 1);
    });
  });

  group('ensure', () {
    testWidgets('asks the system when it never has', (tester) async {
      final phone = _Phone(enabled: false);
      late bool result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await phone.permission.ensure(
                context,
                reason: 'why',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await _settle(tester);
      expect(phone.prompts, 1);
      expect(result, isTrue);
      expect(find.text('Notifications are off'), findsNothing);
    });

    testWidgets('after a refusal it explains and opens Settings', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'notifications.asked': true});
      final phone = _Phone(enabled: false, grants: false);
      late bool result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await phone.permission.ensure(
                context,
                reason: 'So you hear back.',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await _settle(tester);

      expect(phone.prompts, 0, reason: 'the OS would not prompt again');
      expect(find.text('Notifications are off'), findsOneWidget);
      expect(find.textContaining('So you hear back.'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await _settle(tester);
      expect(phone.settingsOpened, 1);
      expect(result, isTrue);
    });
  });

  group('onboarding step', () {
    testWidgets('turning notifications on asks the phone, then moves on', (
      tester,
    ) async {
      final phone = _Phone(enabled: false);
      var done = 0;
      await tester.pumpWidget(
        _wrap(
          NotificationsSetupScreen(
            permission: phone.permission,
            onDone: () => done++,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Don\'t miss what matters'), findsOneWidget);
      expect(find.text('Your therapy sessions'), findsOneWidget);

      await tester.tap(find.text('Turn on notifications'));
      await _settle(tester);
      expect(phone.prompts, 1);
      expect(done, 1);
    });

    testWidgets('maybe later moves on without asking', (tester) async {
      final phone = _Phone(enabled: false);
      var done = 0;
      await tester.pumpWidget(
        _wrap(
          NotificationsSetupScreen(
            permission: phone.permission,
            onDone: () => done++,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Maybe later'));
      await _settle(tester);
      expect(phone.prompts, 0);
      expect(done, 1);
      // The next launch still gets its one system prompt.
      expect(await phone.permission.status(), NotificationAccess.notAsked);
    });
  });

  group('therapy screen', () {
    testWidgets(
      'warns while a session is on the way and notifications are off',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(600, 2400);
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({'notifications.asked': true});
        final phone = _Phone(enabled: false, grants: false);
        await tester.pumpWidget(
          _wrap(
            TherapyScreen(
              repository: _FakeTherapy([_request(status: 'confirmed')]),
              notifications: phone.permission,
              clock: () => _now,
            ),
          ),
        );
        await _settle(tester);

        expect(
          find.textContaining('won\'t get the ten-minute reminder'),
          findsOneWidget,
        );
        await tester.tap(find.text('Turn on'));
        await _settle(tester);
        // Refused before, so the shortest route is Settings.
        expect(find.text('Notifications are off'), findsOneWidget);
        await tester.tap(find.text('Open settings'));
        await _settle(tester);
        expect(phone.settingsOpened, 1);
        expect(
          find.textContaining('won\'t get the ten-minute reminder'),
          findsNothing,
        );
      },
    );

    testWidgets('says nothing when notifications are on', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 2400);
      addTearDown(tester.view.reset);
      final phone = _Phone(enabled: true);
      await tester.pumpWidget(
        _wrap(
          TherapyScreen(
            repository: _FakeTherapy([_request()]),
            notifications: phone.permission,
            clock: () => _now,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(NotificationsOffBanner), findsNothing);
    });
  });
}
