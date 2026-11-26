import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_tags.dart';
import 'package:yournotalone/discover/taste_store.dart';
import 'package:yournotalone/engagement/next_step.dart';
import 'package:yournotalone/practice/feeling_store.dart';
import 'package:yournotalone/practice/practice_repository.dart';

void main() {
  final now = DateTime(2026, 11, 25, 15);

  FeelingRecord felt(
    PracticeKind kind,
    String slug,
    Feeling feeling, {
    int daysAgo = 1,
  }) => FeelingRecord(
    kind: kind,
    slug: slug,
    feeling: feeling,
    at: now.subtract(Duration(days: daysAgo)),
  );

  ContentItem item(String id) => contentIndex.singleWhere((i) => i.id == id);

  group('what helped', () {
    test('close-out answers become items that helped, or didn\'t', () {
      final taste = Taste.from(
        feelings: [
          felt(PracticeKind.breathing, 'Box breathing', Feeling.better),
          felt(PracticeKind.breathing, 'Box breathing', Feeling.same),
          felt(PracticeKind.meditation, 'Deep rest', Feeling.worse),
          // Too long ago to count.
          felt(PracticeKind.meditation, 'Deep rest', Feeling.better, daysAgo: 120),
        ],
        dismissals: const {},
        now: now,
      );
      expect(taste.helped, {'breathing:Box breathing'});
      expect(taste.unhelpful, {'meditation:Deep rest'});
    });

    test('better and worse in equal measure is neither', () {
      final taste = Taste.from(
        feelings: [
          felt(PracticeKind.breathing, 'Box breathing', Feeling.better),
          felt(PracticeKind.breathing, 'Box breathing', Feeling.worse),
        ],
        dismissals: const {},
        now: now,
      );
      expect(taste.helped, isEmpty);
      expect(taste.unhelpful, isEmpty);
    });
  });

  group('not for me', () {
    test('lasts a month', () {
      final taste = Taste.from(
        feelings: const [],
        dismissals: {
          'sound:Heartbeat': now.subtract(const Duration(days: 29)),
          'sound:Breathe': now.subtract(const Duration(days: 31)),
        },
        now: now,
      );
      expect(taste.dismissed, {'sound:Heartbeat'});
      expect(taste.dismissedKinds, isEmpty);
    });

    test('three of one kind turns the kind down', () {
      final sounds = contentIndex
          .where((i) => i.kind == ContentKind.sound)
          .take(3)
          .map((i) => i.id);
      final taste = Taste.from(
        feelings: const [],
        dismissals: {for (final id in sounds) id: now},
        now: now,
      );
      expect(taste.dismissedKinds, {ContentKind.sound});
    });
  });

  group('suggestions use it', () {
    test('a dismissed item is never suggested', () {
      final first = recommend(needs: {Need.panic}, now: now, premium: true, count: 1);
      expect(first, isNotEmpty);
      final again = recommend(
        needs: {Need.panic},
        now: now,
        premium: true,
        count: 20,
        taste: Taste(dismissed: {first.single.id}),
      );
      expect(again.map((i) => i.id), isNot(contains(first.single.id)));
    });

    test('what helped comes first among equal fits', () {
      final picks = recommend(needs: {Need.sleep}, now: now, premium: true, count: 30);
      final last = picks.last;
      final helped = recommend(
        needs: {Need.sleep},
        now: now,
        premium: true,
        count: 1,
        taste: Taste(helped: {last.id}),
      );
      expect(helped.single.id, last.id);
    });

    test('the pick says when it helped before', () {
      final plain = chooseNextStep(now: now, premium: true, taste: Taste.empty)!;
      expect(plain.reason, NextStepReason.timeOfDay);
      final step = chooseNextStep(
        now: now,
        premium: true,
        taste: Taste(helped: {plain.item.id}),
      )!;
      expect(step.item.id, plain.item.id);
      expect(step.reason, NextStepReason.helpedBefore);
    });
  });

  group('at night', () {
    final threeAm = DateTime(2026, 11, 25, 3);

    test('the tool for lying awake, for those who can open it', () {
      final step = chooseNextStep(now: threeAm, premium: true, taste: Taste.empty)!;
      expect(step.item.id, awakeToolId);
      expect(step.reason, NextStepReason.night);
    });

    test('otherwise something to listen to or breathe with, never a read', () {
      for (final premium in [true, false]) {
        final step = chooseNextStep(
          now: threeAm,
          premium: premium,
          taste: const Taste(dismissed: {awakeToolId}),
          // Even with a short night and a strained body to point at.
          signals: const [],
        )!;
        expect(step.reason, NextStepReason.night);
        expect(step.item.id, isNot(awakeToolId));
        expect(fitsTheNight(step.item), isTrue);
        expect(step.item.kind, isNot(ContentKind.lesson));
        expect(step.item.kind, isNot(ContentKind.prompt));
        expect(deepContent, isNot(contains(step.item.id)));
        if (!premium) expect(step.item.premium, isFalse);
      }
    });

    test('the tool exists under that id', () {
      expect(item(awakeToolId).kind, ContentKind.tool);
    });
  });
}
