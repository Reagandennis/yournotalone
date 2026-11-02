// One-time export of the Dart catalogues into `content/` (see
// docs/backend-design.md §8). Kept so the export can be re-run while the
// Dart catalogues are still the source of truth; once content is edited in
// `content/`, delete this.
//
//   flutter test tool/export_content_test.dart
//
// Lives outside test/ so a normal `flutter test` doesn't rewrite content.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/cbt/cbt_catalog.dart';
import 'package:yournotalone/cbt/cbt_content.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_icons.dart';
import 'package:yournotalone/courses/course_catalog.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/journal/journal_prompts.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/recovery/recovery_screen.dart';
import 'package:yournotalone/sleep/sleep_catalog.dart';
import 'package:yournotalone/sleep/sleep_content.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/stress/stress_catalog.dart';
import 'package:yournotalone/stress/stress_content.dart';
import 'package:yournotalone/toolkit/toolkit_content.dart';

/// Recovery items that open an app screen, by title.
const _recoveryScreens = {
  'HALT check': 'halt',
  'Play the tape forward': 'tape-forward',
  'Milestones': 'milestones',
  'Trigger insights': 'trigger-insights',
  'My commitments': 'recovery-hub',
  'Trigger tracker': 'recovery-hub',
};

String _accent(Color c) {
  for (final e in contentAccents.entries) {
    if (e.value == c) return e.key;
  }
  return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

String _icon(IconData icon) {
  for (final e in contentIcons.entries) {
    if (e.value == icon) return e.key;
  }
  throw StateError('Icon ${icon.codePoint} missing from contentIcons');
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

// ── A small YAML writer: strings are double-quoted JSON, which is valid
//    YAML and keeps every quote, dash and accent intact; plain names
//    stay bare. ─────────────────

/// Names (`air_rounded`, `sleep`) stay bare; prose is quoted.
final _bare = RegExp(r'^[a-z][a-z0-9_-]*$');
const _reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', 'y', 'n'};

String _scalar(Object v) => v is! String
    ? '$v'
    : _bare.hasMatch(v) && !_reserved.contains(v)
    ? v
    : jsonEncode(v);

void _write(StringBuffer out, Map<String, Object?> map, int indent) {
  final pad = ' ' * indent;
  for (final MapEntry(:key, :value) in map.entries) {
    if (value == null) continue;
    if (value is Map<String, Object?>) {
      out.writeln('$pad$key:');
      _write(out, value, indent + 2);
    } else if (value is List) {
      if (value.isEmpty) {
        out.writeln('$pad$key: []');
      } else if (value.every((v) => v is! String || v.length < 30) &&
          value.length <= 6) {
        out.writeln('$pad$key: [${value.map((v) => _scalar(v!)).join(', ')}]');
      } else {
        out.writeln('$pad$key:');
        for (final v in value) {
          out.writeln('$pad  - ${_scalar(v!)}');
        }
      }
    } else {
      out.writeln('$pad$key: ${_scalar(value)}');
    }
  }
}

final _byId = {for (final i in contentIndex) i.id: i};

/// The fields every item shares, read from the index so the tags are the
/// final merged ones (catalogue defaults plus `content_tags.dart`).
Map<String, Object?> _item(
  String id, {
  required Map<String, Object?> text,
  required Map<String, Object?> body,
}) {
  final item = _byId[id];
  if (item == null) throw StateError('$id is not in the content index');
  final added = item.addedOn;
  return {
    'id': id,
    'kind': item.kind.name,
    'status': 'published',
    // Where it sits in lists; gaps of 10 leave room to slot new items in.
    'order': (contentIndex.indexOf(item) + 1) * 10,
    'premium': item.premium,
    'addedOn': added == null
        ? null
        : '${added.year}-${'${added.month}'.padLeft(2, '0')}-'
              '${'${added.day}'.padLeft(2, '0')}',
    'minutes': item.minutes,
    'icon': _icon(item.icon),
    'accent': _accent(item.accent),
    'tags': {
      'needs': [
        for (final n in Need.values)
          if (item.needs.contains(n)) n.name,
      ],
      'dayParts': [
        for (final d in DayPart.values)
          if (item.dayParts.contains(d)) d.name,
      ],
    },
    'text': {
      'en': {
        'title': item.title,
        'blurb': item.blurb,
        'area': item.area,
        ...text,
      },
    },
    'body': body,
  };
}

Map<String, Object?> _meditationBody(Meditation m) => {
  'type': 'meditation',
  'promptAt': [for (final (at, _) in m.prompts) at],
  'narration': m.narration,
};

List<Map<String, Object?>> _toolkit(
  List<ToolkitTool> tools,
  List<ToolkitLesson> lessons,
) => [
  for (final t in tools)
    if (t.guard == null)
      _item(
        'tool:${t.title}',
        text: {'meta': t.meta},
        body: {'type': 'native', 'screen': _slug(t.title), 'art': t.art.name},
      ),
  for (final l in lessons)
    _item(
      'lesson:${l.title}',
      text: {'paragraphs': l.paragraphs},
      body: {'type': 'lesson', 'art': l.art.name},
    ),
];

void main() {
  test('export catalogues to content/', () {
    final items = <Map<String, Object?>>[
      for (final p in breathPatterns)
        _item(
          'breathing:${p.title}',
          text: const {},
          body: {
            'type': 'breathing',
            'inhale': p.inhale,
            'holdIn': p.holdIn,
            'exhale': p.exhale,
            'holdOut': p.holdOut,
          },
        ),
      for (final m in meditations)
        _item(
          'meditation:${m.title}',
          text: {
            'prompts': [for (final (_, line) in m.prompts) line],
          },
          body: _meditationBody(m),
        ),
      for (final s in soundsCatalog)
        _item(
          'sound:${s.title}',
          text: const {},
          body: {
            'type': 'sound',
            'category': s.category.name,
            'audio': s.asset,
            'loop': true,
            'waveFreq': s.waveFreq,
            'waveSpeed': s.waveSpeed,
            'waveHeight': s.waveHeight,
            'pulse': s.pulse,
          },
        ),
      for (final p in journalPrompts)
        _item(
          'prompt:${p.title}',
          text: {'seed': p.seed},
          body: {'type': 'prompt', 'group': p.group},
        ),
      ..._toolkit(cbtTools, cbtLessons),
      ..._toolkit(sleepTools, sleepLessons),
      ..._toolkit(stressTools, stressLessons),
      _item(
        'recovery:${urgeSurfMeditation.title}',
        text: {
          'prompts': [for (final (_, line) in urgeSurfMeditation.prompts) line],
        },
        body: _meditationBody(urgeSurfMeditation),
      ),
      for (final MapEntry(key: title, value: screen)
          in _recoveryScreens.entries)
        _item(
          'recovery:$title',
          text: const {},
          body: {'type': 'native', 'screen': screen},
        ),
    ];

    final exported = {for (final i in items) i['id']};
    final missing = _byId.keys.where((id) => !exported.contains(id)).toList();
    expect(missing, isEmpty, reason: 'index items with no export');

    final root = Directory('content');
    if (root.existsSync()) root.deleteSync(recursive: true);

    final names = <String>{};
    for (final item in items) {
      final kind = item['kind']! as String;
      final title = ((item['text']! as Map)['en'] as Map)['title'] as String;
      final path = 'content/items/$kind/${_slug(title)}.yaml';
      expect(names.add(path), isTrue, reason: 'two items would share $path');
      final out = StringBuffer();
      _write(out, item, 0);
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(out.toString());
    }

    for (final c in courses) {
      final out = StringBuffer();
      _write(out, {
        'id': c.id,
        'status': 'published',
        'order': (courses.indexOf(c) + 1) * 10,
        'icon': _icon(c.icon),
        'accent': _accent(c.accent),
        'need': c.need.name,
        'days': [for (final d in c.days) d.itemId],
        'text': {
          'en': {
            'title': c.title,
            'blurb': c.blurb,
            'notes': [for (final d in c.days) d.note],
          },
        },
      }, 0);
      File('content/courses/${c.id}.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(out.toString());
    }

    final vocab = StringBuffer();
    _write(vocab, {
      'locales': ['en', 'fr', 'de', 'es', 'zh-Hans'],
      'kinds': [for (final k in ContentKind.values) k.name],
      'needs': [for (final n in Need.values) n.name],
      'dayParts': [for (final d in DayPart.values) d.name],
      'accents': [...contentAccents.keys],
      'soundCategories': [for (final c in SoundCategory.values) c.name],
      'promptGroups': promptGroups,
    }, 0);
    File('content/vocab.yaml').writeAsStringSync(vocab.toString());
  });
}
