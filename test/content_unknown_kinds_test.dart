import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/content/catalog_snapshot.dart';

/// A published catalogue can carry a kind of item, or a course for a need,
/// that an older app doesn't know. Those are skipped; the rest still loads.
/// One unknown name used to reject the whole catalogue, so older apps got
/// no updates at all.
void main() {
  final json =
      jsonDecode(File(bundledCatalogAsset).readAsStringSync())
          as Map<String, dynamic>;
  final items = (json['items'] as List).cast<Map<String, dynamic>>();
  final courses = (json['courses'] as List).cast<Map<String, dynamic>>();

  test('an item of an unknown kind is skipped, the rest loads', () {
    final read = CatalogSnapshot.fromJson({
      ...json,
      'items': [
        {...items.first, 'id': 'hologram:New thing', 'kind': 'hologram'},
        ...items,
      ],
    });
    expect(read, isNotNull);
    expect(read!.items, hasLength(items.length));
    expect(read.items.map((i) => i.id), isNot(contains('hologram:New thing')));
  });

  test('a course for an unknown need is skipped, the rest loads', () {
    expect(courses, isNotEmpty);
    final read = CatalogSnapshot.fromJson({
      ...json,
      'courses': [
        {...courses.first, 'id': 'course-future', 'need': 'wanderlust'},
        ...courses,
      ],
    });
    expect(read, isNotNull);
    expect(read!.courses, hasLength(courses.length));
    expect(read.courses.map((c) => c.id), isNot(contains('course-future')));
    expect(read.items, hasLength(items.length));
  });
}
