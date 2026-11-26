/// The home-screen and lock-screen widgets: what the app hands them, and
/// where a tap on one leads.
///
/// The widgets themselves are native — a WidgetKit extension on iOS
/// (ios/HomeWidgets/) and two app widgets on Android
/// (android/app/src/main/kotlin/…/HomeWidgets.kt) — and only display. Every
/// word they show is written here, already in the app's language, so the
/// native side needs no translations of its own beyond its gallery name.
///
/// A widget sits on a screen anyone holding the phone can see. So it shows
/// how the week is going and today's suggestion, and — only when someone
/// has connected their health data and left it on for the widget — last
/// night's sleep as a length of time. Never a mood, a journal line or a
/// heart reading.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app_navigation.dart';
import '../discover/content_index.dart';
import '../home/home_shell.dart';
import '../l10n/l10n.dart';
import '../practice/practice_repository.dart';
import '../therapy/call_screen.dart';

/// Shared with the widget extension (both targets' entitlements).
const homeWidgetAppGroup = 'group.com.techgetafrica.yournotalone';

/// The scheme of a widget tap (registered in ios/Runner/Info.plist).
const homeWidgetScheme = 'yournotalone-widget';

/// The iOS widget's `kind` (ios/HomeWidgets/HomeWidgets.swift).
const _iosKind = 'HomeWidgets';

/// The Android providers (HomeWidgets.kt), by their full class names.
const _androidProviders = [
  'com.techgetafrica.yournotalone.RhythmWidgetProvider',
  'com.techgetafrica.yournotalone.TodayWidgetProvider',
];

/// What the widgets show, gathered by the app when it has fresh numbers.
@immutable
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.daysThisWeek,
    required this.goal,
    required this.week,
    required this.todayIndex,
    required this.checkedInToday,
    this.pickId,
    this.pickTitle,
    this.pickMeta,
    this.sleepMinutes,
  }) : assert(week.length == 7);

  /// Days shown up on this week, and the weekly goal (see Rhythm).
  final int daysThisWeek;
  final int goal;

  /// This week, Monday first.
  final List<bool> week;
  final int todayIndex;

  /// Whether today's mood check-in is done.
  final bool checkedInToday;

  /// Today's suggestion: its content id (what a tap opens), title and
  /// "Meditation · 5 min" line. Null when there's none.
  final String? pickId;
  final String? pickTitle;
  final String? pickMeta;

  /// Last night's sleep, or null to leave sleep off the widget (not
  /// connected, nothing recorded, or turned off for the widget).
  final int? sleepMinutes;
}

/// Every key the widgets read. Kept in one place so [HomeWidgetSync.clear]
/// can't miss one, and so the native readers have one list to match.
abstract final class HomeWidgetKeys {
  /// `ready` with someone's week, or `signedOut` for the neutral face.
  static const state = 'hw_state';

  /// The calendar day the numbers are from, and that week's Monday, as
  /// `YYYY-MM-DD`: the widget can outlive the day it was written on, and
  /// shows a fresh day or week rather than yesterday's ticks.
  static const day = 'hw_day';
  static const weekStart = 'hw_week_start';

  static const days = 'hw_days';
  static const goal = 'hw_goal';

  /// Seven characters, Monday first: `1` shown up, `0` not.
  static const week = 'hw_week';
  static const checkedIn = 'hw_checked_in';
  static const pickId = 'hw_pick_id';
  static const pickTitle = 'hw_pick_title';
  static const pickMeta = 'hw_pick_meta';
  static const sleepLine = 'hw_sleep_line';

  // Words, already in the app's language.
  static const labelWeek = 'hw_label_week';
  static const labelDays = 'hw_label_days';

  /// The same line for a week that's just begun ("0 of 3 days"), for when
  /// the widget is showing a new week the app hasn't seen yet.
  static const labelDaysZero = 'hw_label_days_zero';
  static const labelGoalMet = 'hw_label_goal_met';
  static const labelCheckIn = 'hw_label_check_in';
  static const labelCheckedIn = 'hw_label_checked_in';
  static const labelForYou = 'hw_label_for_you';
  static const labelOpenForPick = 'hw_label_open_for_pick';

  /// What's about one person, wiped on sign-out.
  static const personal = [
    day,
    weekStart,
    days,
    goal,
    week,
    checkedIn,
    pickId,
    pickTitle,
    pickMeta,
    sleepLine,
    labelDays,
    labelDaysZero,
  ];

  static const labels = [
    labelWeek,
    labelGoalMet,
    labelCheckIn,
    labelCheckedIn,
    labelForYou,
    labelOpenForPick,
  ];
}

/// The words every face of the widget uses, signed in or not.
Map<String, Object?> homeWidgetLabels(AppLocalizations l10n) => {
  HomeWidgetKeys.labelWeek: l10n.widgetThisWeek,
  HomeWidgetKeys.labelGoalMet: l10n.widgetGoalMet,
  HomeWidgetKeys.labelCheckIn: l10n.widgetCheckIn,
  HomeWidgetKeys.labelCheckedIn: l10n.widgetCheckedIn,
  HomeWidgetKeys.labelForYou: l10n.widgetForYou,
  HomeWidgetKeys.labelOpenForPick: l10n.widgetOpenForPick,
};

/// What [snapshot] is stored as. Pure, so it's tested without a phone.
Map<String, Object?> homeWidgetData(
  HomeWidgetSnapshot snapshot,
  AppLocalizations l10n,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  // From the calendar date, not a Duration, so a clock change can't move
  // Monday onto Sunday.
  final monday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  final goal = snapshot.goal.clamp(1, 7);
  final sleep = snapshot.sleepMinutes;
  final title = snapshot.pickTitle?.trim();
  final hasPick = snapshot.pickId != null && title != null && title.isNotEmpty;
  return {
    HomeWidgetKeys.state: 'ready',
    HomeWidgetKeys.day: PracticeRepository.dateKey(today),
    HomeWidgetKeys.weekStart: PracticeRepository.dateKey(monday),
    HomeWidgetKeys.days: snapshot.daysThisWeek,
    HomeWidgetKeys.goal: goal,
    HomeWidgetKeys.week: [for (final d in snapshot.week) d ? '1' : '0'].join(),
    HomeWidgetKeys.checkedIn: snapshot.checkedInToday,
    HomeWidgetKeys.pickId: hasPick ? snapshot.pickId : null,
    HomeWidgetKeys.pickTitle: hasPick ? title : null,
    HomeWidgetKeys.pickMeta: hasPick ? snapshot.pickMeta : null,
    HomeWidgetKeys.sleepLine: sleep == null || sleep <= 0
        ? null
        : l10n.widgetSleepLine(sleep ~/ 60, sleep % 60),
    HomeWidgetKeys.labelDays: l10n.widgetDaysOfGoal(
      snapshot.daysThisWeek,
      goal,
    ),
    HomeWidgetKeys.labelDaysZero: l10n.widgetDaysOfGoal(0, goal),
    ...homeWidgetLabels(l10n),
  };
}

/// Hands the widgets their numbers and words, and hears their taps.
class HomeWidgetSync {
  HomeWidgetSync._();

  static final instance = HomeWidgetSync._();

  /// Widget tests have no plugin to talk to.
  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  static bool get _supported => Platform.isIOS || Platform.isAndroid;

  Future<void>? _groupSet;

  /// The app group, set once before the first write on iOS.
  Future<void> _ready() {
    if (!Platform.isIOS) return Future.value();
    return _groupSet ??= HomeWidget.setAppGroupId(homeWidgetAppGroup)
        .then((_) {})
        .catchError((Object e) {
          // Tried again next time rather than kept as the answer.
          _groupSet = null;
          throw e;
        });
  }

  /// Writes [snapshot] and redraws the widgets. Never throws: a widget
  /// that couldn't be updated keeps showing the last good numbers.
  Future<void> update(HomeWidgetSnapshot snapshot) async {
    if (_silent || !_supported) return;
    try {
      await _ready();
      await _write(homeWidgetData(snapshot, currentL10n(), DateTime.now()));
      await _redraw();
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    }
  }

  /// Sign-out and account deletion: nothing about the person stays on the
  /// home screen, and the widget shows its neutral "open the app" face.
  Future<void> clear() async {
    if (_silent || !_supported) return;
    try {
      await _ready();
      await _write({
        HomeWidgetKeys.state: 'signedOut',
        for (final key in HomeWidgetKeys.personal) key: null,
        ...homeWidgetLabels(currentL10n()),
      });
      await _redraw();
    } catch (e) {
      debugPrint('Home widget clear failed: $e');
    }
  }

  Future<void> _write(Map<String, Object?> data) async {
    for (final MapEntry(:key, :value) in data.entries) {
      await HomeWidget.saveWidgetData<Object>(key, value);
    }
  }

  Future<void> _redraw() async {
    if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: _iosKind);
    } else {
      for (final provider in _androidProviders) {
        await HomeWidget.updateWidget(qualifiedAndroidName: provider);
      }
    }
  }

  StreamSubscription<Uri?>? _clicks;

  /// Calls [onOpen] for every widget tap: the one that launched the app,
  /// and each one while it runs. Calling it again replaces the listener.
  void listen(void Function(Uri uri) onOpen) {
    if (_silent || !_supported) return;
    void handle(Uri? uri) {
      // The plugin hands an empty Uri for a launch it couldn't read.
      if (uri != null && uri.scheme == homeWidgetScheme) onOpen(uri);
    }

    _clicks?.cancel();
    _clicks = HomeWidget.widgetClicked.listen(
      handle,
      onError: (Object e) => debugPrint('Home widget taps unavailable: $e'),
    );
    HomeWidget.initiallyLaunchedFromHomeWidget().then(handle).catchError((
      Object e,
    ) {
      debugPrint('Home widget launch unreadable: $e');
    });
  }
}

/// Where a widget tap leads: the check-in to the mood card on Home, the
/// suggestion straight into it (through [openContent], so Premium is still
/// checked). In a therapy call, nothing moves.
void openFromHomeWidget(NavigatorState navigator, Uri uri) {
  final kind = switch (uri.host) {
    'checkin' => 'checkin',
    'pick' => 'pick',
    _ => null,
  };
  if (kind == null) return;
  Sentry.metrics.count(
    'widget.opened',
    1,
    attributes: {'kind': SentryAttribute.string(kind)},
  );
  if (appRoutes.isOpen(CallScreen.routeName)) return;
  navigator.popUntil((route) => route.isFirst);
  if (kind == 'checkin') {
    homeTabRequest.value = 0;
    return;
  }
  final id = uri.queryParameters['id'];
  // Gone from the catalogue since the widget was written: Home instead.
  final item = id == null
      ? null
      : contentIndex.where((i) => i.id == id).firstOrNull;
  if (item == null) {
    homeTabRequest.value = 0;
    return;
  }
  openContent(navigator.context, item, source: 'widget');
}
