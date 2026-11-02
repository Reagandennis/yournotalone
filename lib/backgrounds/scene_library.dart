import 'package:flutter/material.dart';

import '../content/catalog_snapshot.dart';
import '../discover/content_index.dart';
import 'background_spec.dart';

/// The backgrounds on offer and which item opens with which.
///
/// They come from the catalogue snapshot whether or not the screens read
/// their content from it: with `CATALOG_SNAPSHOT` on, `ContentCatalog`
/// hands over the snapshot it uses (possibly a newer, downloaded one);
/// without it, [load] reads the bundled snapshot asset, which is in every
/// build. Until either has happened — or if neither has any backgrounds —
/// there is [fallbackBackground], so a screen always has something to
/// draw.
class SceneLibrary extends ChangeNotifier {
  SceneLibrary._();

  static final instance = SceneLibrary._();

  List<BackgroundSpec> _backgrounds = const [];
  Map<String, String> _preferred = const {};
  bool _used = false;

  /// In list order; never empty.
  List<BackgroundSpec> get backgrounds =>
      _backgrounds.isEmpty ? const [fallbackBackground] : _backgrounds;

  /// Reads the bundled snapshot, unless a catalogue has already been
  /// handed over. Never throws.
  Future<void> load() async {
    if (_used) return;
    try {
      final bundled = await CatalogSnapshot.bundled();
      if (!_used) use(bundled);
    } catch (e) {
      debugPrint('Backgrounds unavailable, using the built-in one: $e');
    }
  }

  void use(CatalogSnapshot snapshot) {
    _used = true;
    _backgrounds = snapshot.backgrounds;
    _preferred = {for (final i in snapshot.items) i.id: ?i.background};
    notifyListeners();
  }

  BackgroundSpec? byId(String? id) {
    for (final b in backgrounds) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// What [itemId] opens with when the person hasn't picked: its own
  /// preference, else its kind's default, else the first background.
  BackgroundSpec defaultFor(String itemId, ContentKind kind) =>
      byId(_preferred[itemId]) ??
      backgrounds.firstWhere(
        (b) => b.defaultFor.contains(kind),
        orElse: () => backgrounds.first,
      );

  /// [choice] (the person's pick) when it's still on offer, else
  /// [defaultFor].
  BackgroundSpec backgroundFor(
    String itemId,
    ContentKind kind, {
    String? choice,
  }) => byId(choice) ?? defaultFor(itemId, kind);

  @visibleForTesting
  void reset() {
    _backgrounds = const [];
    _preferred = const {};
    _used = false;
  }
}
