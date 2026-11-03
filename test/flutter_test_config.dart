import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';

import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';

/// Every test runs with the catalogue read from the bundled snapshot, the
/// way the app runs. `--dart-define=CATALOG_SNAPSHOT=false` runs them on the
/// Dart catalogues instead.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // As in main(): date names for every language, delegate or not.
  await initializeDateFormatting();
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
