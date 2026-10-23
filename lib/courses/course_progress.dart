import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'course_catalog.dart';

/// Where someone is in one course: the date each day was done.
class CourseProgress {
  const CourseProgress({this.done = const {}, this.lastTouched});

  /// Day index → the calendar day it was done.
  final Map<int, DateTime> done;
  final DateTime? lastTouched;

  bool get started => done.isNotEmpty;

  bool finished(Course course) => done.length >= course.days.length;

  /// The first day not done yet, or null when the course is finished.
  int? nextDay(Course course) {
    for (var i = 0; i < course.days.length; i++) {
      if (!done.containsKey(i)) return i;
    }
    return null;
  }

  /// One step a day: the next day opens on the calendar day after the one
  /// before it was done.
  bool isOpen(Course course, int day, DateTime now) {
    if (done.containsKey(day)) return true;
    if (day != nextDay(course)) return false;
    if (day == 0) return true;
    final previous = done[day - 1];
    if (previous == null) return false;
    return DateUtils.dateOnly(now).isAfter(DateUtils.dateOnly(previous));
  }

  Map<String, dynamic> toJson() => {
    'done': {
      for (final e in done.entries) '${e.key}': e.value.toIso8601String(),
    },
    if (lastTouched != null) 'touched': lastTouched!.toIso8601String(),
  };

  factory CourseProgress.fromJson(Map<String, dynamic> json) => CourseProgress(
    done: {
      for (final e in (json['done'] as Map? ?? {}).entries)
        int.parse(e.key as String): DateTime.parse(e.value as String),
    },
    lastTouched: json['touched'] == null
        ? null
        : DateTime.parse(json['touched'] as String),
  );
}

/// Course progress for everyone on this device, by course id.
class CourseStore extends ValueNotifier<Map<String, CourseProgress>> {
  CourseStore._() : super(const {});

  static final instance = CourseStore._();

  static const _key = 'courses.progress';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      value = {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: CourseProgress.fromJson(Map<String, dynamic>.from(e.value)),
      };
    } catch (e) {
      debugPrint('Course progress unavailable: $e');
    }
  }

  CourseProgress of(Course course) =>
      value[course.id] ?? const CourseProgress();

  Future<void> completeDay(Course course, int day, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final current = of(course);
    if (current.done.containsKey(day)) return;
    value = {
      ...value,
      course.id: CourseProgress(
        done: {...current.done, day: at},
        lastTouched: at,
      ),
    };
    Sentry.metrics.count(
      'course.day_done',
      1,
      attributes: {
        'course': SentryAttribute.string(course.id),
        'day': SentryAttribute.string('${day + 1}'),
      },
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({for (final e in value.entries) e.key: e.value.toJson()}),
      );
    } catch (e) {
      debugPrint('Couldn\'t save course progress: $e');
    }
  }

  /// The course someone is part-way through, most recently touched first.
  Course? get active {
    Course? best;
    DateTime? bestAt;
    for (final course in courses) {
      final p = of(course);
      if (!p.started || p.finished(course)) continue;
      final at = p.lastTouched ?? DateTime(2000);
      if (bestAt == null || at.isAfter(bestAt)) {
        best = course;
        bestAt = at;
      }
    }
    return best;
  }

  @visibleForTesting
  void reset() {
    _loaded = false;
    value = const {};
  }
}
