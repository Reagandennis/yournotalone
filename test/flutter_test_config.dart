import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';

/// `flutter test --dart-define=CATALOG_SNAPSHOT=true` runs every test with
/// the catalogue read from the bundled snapshot instead of the Dart
/// catalogues, the way the app runs with the same flag.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (catalogSnapshotEnabled) {
    ContentCatalog.instance.use(
      CatalogSnapshot.fromJson(
        jsonDecode(File(bundledCatalogAsset).readAsStringSync())
            as Map<String, dynamic>,
      )!,
    );
  }
  await testMain();
}
