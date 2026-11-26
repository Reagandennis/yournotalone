import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/notifications/session_notifications.dart';

final _start = DateTime.utc(2026, 9, 14, 11);

Map<String, dynamic> _session({
  String id = 's1',
  String role = 'client',
  String payment = 'paid',
  DateTime? at,
  bool free = false,
}) =>
    {
      'request_id': id,
      'role': role,
      'scheduled_at': (at ?? _start).toIso8601String(),
      'duration_minutes': 50,
      'topic': 'Low mood',
      'payment_status': free ? 'not_required' : payment,
      'price_cents': free ? 0 : 2000,
      'is_free_session': free,
      'counterpart': role == 'client' ? 'Tess Mwangi' : 'Anna',
    };

void main() {
  group('what a notification says', () {
    final tenBefore = _start.subtract(const Duration(minutes: 10));

    test('a client hears who they\'re matched with and what to pay', () {
      final text = describeSessionNotification(
          'session_booked', _session(payment: 'unpaid'), tenBefore);
      expect(text.title, 'You\'re matched with Tess Mwangi');
      expect(text.body, contains('50 min.'));
      expect(text.body, contains('Pay \$20 in the app'));
    });

    test('the topic never reaches the lock screen', () {
      for (final kind in [
        'session_booked',
        'session_changed',
        'session_cancelled',
        'session_reminder',
      ]) {
        for (final role in ['client', 'therapist']) {
          final text = describeSessionNotification(
              kind, _session(role: role), tenBefore);
          expect(text.title, isNot(contains('Low mood')), reason: kind);
          expect(text.body, isNot(contains('Low mood')), reason: kind);
        }
      }
    });

    test('a paid booking needs nothing more from the client', () {
      final text = describeSessionNotification(
          'session_booked', _session(), tenBefore);
      expect(text.body, endsWith('You\'re all set.'));
    });

    test('a missed session says it isn\'t refunded, without the topic', () {
      final text = describeSessionNotification(
          'session_missed', _session(), tenBefore);
      expect(text.title, 'You missed your session');
      expect(text.body, contains('isn\'t refunded'));
      expect(text.body, isNot(contains('Low mood')));
    });

    test('a therapist hears only the client\'s first name', () {
      final text = describeSessionNotification(
          'session_booked', _session(role: 'therapist'), tenBefore);
      expect(text.title, 'New session with Anna');
      expect(text.body, isNot(contains('Pay')));
    });

    test('the reminder counts down to the start', () {
      final text = describeSessionNotification(
          'session_reminder', _session(), tenBefore);
      expect(text.title, 'Your session starts in 10 minutes');
      expect(text.body, endsWith('Open the app to join.'));

      final unpaid = describeSessionNotification(
          'session_reminder', _session(payment: 'unpaid'), tenBefore);
      expect(unpaid.body, contains('pay in the app to join'));

      final late = describeSessionNotification(
          'session_reminder', _session(role: 'therapist'), _start);
      expect(late.title, 'Session with Anna is starting now');
    });

    test('a cancellation names who it was with', () {
      final text = describeSessionNotification(
          'session_cancelled', _session(role: 'therapist'), tenBefore);
      expect(text.title, 'Session cancelled');
      expect(text.body, contains('Anna'));
    });
  });

  group('late news', () {
    test('a reminder is pointless once the session is under way', () {
      expect(
        isStaleSessionNotification('session_reminder', _session(),
            _start.add(const Duration(minutes: 5))),
        isFalse,
      );
      expect(
        isStaleSessionNotification('session_reminder', _session(),
            _start.add(const Duration(minutes: 20))),
        isTrue,
      );
    });

    test('a booking stays worth hearing until the session is long over', () {
      expect(
        isStaleSessionNotification('session_booked', _session(),
            _start.add(const Duration(minutes: 100))),
        isFalse,
      );
      expect(
        isStaleSessionNotification('session_booked', _session(),
            _start.add(const Duration(hours: 3))),
        isTrue,
      );
    });
  });

  group('reminders on the phone', () {
    final now = _start.subtract(const Duration(hours: 2));

    test('a new session gets a reminder', () {
      final plan = planSessionReminders([_session()], {}, now);
      expect(plan.schedule.single['request_id'], 's1');
      expect(plan.cancel, isEmpty);
      expect(plan.remembered, {'s1': sessionStartKey(_start.toIso8601String())});
    });

    test('an already scheduled reminder is left alone', () {
      final remembered = {'s1': sessionStartKey(_start.toIso8601String())};
      final plan = planSessionReminders([_session()], remembered, now);
      expect(plan.schedule, isEmpty);
      expect(plan.cancel, isEmpty);
      expect(plan.remembered, remembered);
    });

    test('a moved session swaps its reminder', () {
      final moved = _start.add(const Duration(hours: 1));
      final plan = planSessionReminders(
        [_session(at: moved)],
        {'s1': sessionStartKey(_start.toIso8601String())},
        now,
      );
      expect(plan.cancel, {'s1'});
      expect(plan.schedule.single['scheduled_at'], moved.toIso8601String());
    });

    test('a cancelled session loses its reminder', () {
      final plan = planSessionReminders(
        [],
        {'s1': sessionStartKey(_start.toIso8601String())},
        now,
      );
      expect(plan.cancel, {'s1'});
      expect(plan.remembered, isEmpty);
    });

    test('too late to schedule: the server\'s reminder is left to show', () {
      final plan = planSessionReminders(
        [_session()],
        {},
        _start.subtract(const Duration(minutes: 5)),
      );
      expect(plan.schedule, isEmpty);
      expect(plan.remembered, isEmpty);
    });

    test('ids are stable, distinct per session, and fit Android', () {
      expect(reminderNotificationId('s1'), reminderNotificationId('s1'));
      expect(reminderNotificationId('s1'), isNot(reminderNotificationId('s2')));
      expect(reminderNotificationId('s1'), isNot(sessionNotificationId('s1')));
      expect(sessionNotificationId('s1'), lessThan(1 << 31));
    });
  });

  group('notes before and after a session', () {
    // Local times: when the notes come depends on the phone's day.
    final start = DateTime(2026, 9, 14, 11);
    final key = sessionStartKey(start.toIso8601String());
    final dayBefore = DateTime(2026, 9, 13, 20);
    Map<String, dynamic> at(DateTime t, {String id = 's1', String role = 'client'}) =>
        _session(id: id, role: role, at: t);

    test('an hour before, and that evening', () {
      final plan = planSessionCompanions([at(start)], {}, dayBefore, enabled: true);
      expect(plan.schedule.map((n) => (n.prep, n.at)), [
        (true, DateTime(2026, 9, 14, 10)),
        (false, DateTime(2026, 9, 14, 18)),
      ]);
      expect(plan.remembered, {'s1': key});
      expect(plan.cancel, isEmpty);
    });

    test('the note after comes later in the day, or the next morning', () {
      expect(reflectionTime(DateTime(2026, 9, 14, 11), 50), DateTime(2026, 9, 14, 18));
      expect(reflectionTime(DateTime(2026, 9, 14, 17), 50), DateTime(2026, 9, 14, 19, 20));
      expect(reflectionTime(DateTime(2026, 9, 14, 20), 50), DateTime(2026, 9, 15, 9));
      expect(reflectionTime(DateTime(2026, 9, 14, 23), 50), DateTime(2026, 9, 15, 9));
    });

    test('not for therapists, and none when the check-ins are off', () {
      expect(
        planSessionCompanions([at(start, role: 'therapist')], {}, dayBefore, enabled: true)
            .schedule,
        isEmpty,
      );
      final off = planSessionCompanions([at(start)], {'s1': key}, dayBefore, enabled: false);
      expect(off.schedule, isEmpty);
      expect(off.cancel, {'s1'});
      expect(off.remembered, isEmpty);
    });

    test('booked with under an hour to go: only the note after', () {
      final plan = planSessionCompanions(
        [at(start)],
        {},
        start.subtract(const Duration(minutes: 30)),
        enabled: true,
      );
      expect(plan.schedule.map((n) => n.prep), [false]);
    });

    test('already scheduled is left alone; moved is swapped', () {
      expect(
        planSessionCompanions([at(start)], {'s1': key}, dayBefore, enabled: true).schedule,
        isEmpty,
      );
      final moved = planSessionCompanions(
        [at(start.add(const Duration(days: 1)))],
        {'s1': key},
        dayBefore,
        enabled: true,
      );
      expect(moved.cancel, {'s1'});
      expect(moved.schedule.first.at, DateTime(2026, 9, 15, 10));
    });

    test('gone before it starts: cancelled; gone once begun: the note after stays', () {
      final cancelled = planSessionCompanions([], {'s1': key}, dayBefore, enabled: true);
      expect(cancelled.cancel, {'s1'});
      expect(cancelled.remembered, isEmpty);
      final begun = planSessionCompanions(
        [],
        {'s1': key},
        start.add(const Duration(minutes: 20)),
        enabled: true,
      );
      expect(begun.cancel, isEmpty);
      expect(begun.remembered, {'s1': key});
      // Long over: forgotten, nothing to cancel.
      final over = planSessionCompanions(
        [],
        {'s1': key},
        start.add(const Duration(days: 3)),
        enabled: true,
      );
      expect(over.cancel, isEmpty);
      expect(over.remembered, isEmpty);
    });

    test('their ids are their own and fit Android', () {
      final ids = {
        reminderNotificationId('s1'),
        sessionNotificationId('s1'),
        prepNotificationId('s1'),
        reflectNotificationId('s1'),
      };
      expect(ids, hasLength(4));
      expect(ids.every((id) => id < (1 << 31) - 1), isTrue);
      // Clear of the trial reminder and the meditation end notice.
      expect(prepNotificationId('s1'), greaterThanOrEqualTo(500000000));
    });

    test('the words say nothing about who or what', () {
      final prep = describeSessionCompanion(prep: true);
      final after = describeSessionCompanion(prep: false);
      for (final t in [prep.title, prep.body, after.title, after.body]) {
        expect(t, isNot(contains('Tess')));
        expect(t, isNot(contains('Low mood')));
      }
    });
  });
}
