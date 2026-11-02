import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/saved_store.dart';

/// One account's `saved_items`, shared by the "phones" in a test.
class _Account implements SavedItemsRemote {
  final saved = <String>[]; // newest first
  bool down = false;
  int calls = 0;

  void _check() {
    calls++;
    if (down) throw Exception('offline');
  }

  @override
  Future<List<String>> fetch() async {
    _check();
    return [...saved];
  }

  @override
  Future<void> add(List<String> ids) async {
    _check();
    saved.insertAll(0, ids.where((id) => !saved.contains(id)));
  }

  @override
  Future<void> remove(List<String> ids) async {
    _check();
    saved.removeWhere(ids.contains);
  }
}

ContentItem _item(String title) =>
    builtInContentIndex.firstWhere((i) => i.title == title);

void main() {
  final box = _item('Box breathing');
  final rain = _item('Rainfall');
  late _Account account;
  String? user;

  SavedStore phone() => SavedStore.forTest(remote: account, userId: () => user);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    account = _Account();
    user = 'user-a';
  });

  test('a save reaches the account', () async {
    final store = phone();
    await store.load();
    await store.toggle(box);
    await store.sync();
    expect(account.saved, [box.id]);
    expect(store.isSaved(box), isTrue);
  });

  test('a save made offline is sent once there is a connection', () async {
    final store = phone();
    await store.load();
    account.down = true;
    await store.toggle(box);
    await store.sync();
    expect(store.isSaved(box), isTrue, reason: 'still saved on the phone');
    expect(account.saved, isEmpty);

    account.down = false;
    await store.sync();
    expect(account.saved, [box.id]);
  });

  test('the queue survives the app restarting', () async {
    account.down = true;
    final first = phone();
    await first.load();
    await first.toggle(box);

    account.down = false;
    final restarted = phone();
    await restarted.load();
    await restarted.sync();
    expect(account.saved, [box.id]);
  });

  test('an item unsaved on one phone disappears from the other', () async {
    account.saved.addAll([box.id, rain.id]);
    final a = phone();
    await a.load();
    await a.sync();
    expect(a.value, {box.id, rain.id});

    // The second phone keeps its own prefs.
    final aPrefs = await SharedPreferences.getInstance();
    final aState = {for (final k in aPrefs.getKeys()) k: aPrefs.get(k)!};
    SharedPreferences.setMockInitialValues({});
    final b = phone();
    await b.load();
    await b.sync();
    expect(b.value, {box.id, rain.id});

    SharedPreferences.setMockInitialValues(aState);
    await a.toggle(box);
    await a.sync();

    await b.sync();
    expect(b.value, {rain.id});
  });

  test('saves from before syncing join the account\'s own', () async {
    SharedPreferences.setMockInitialValues({
      'discover.saved': [box.id],
    });
    account.saved.add(rain.id);
    final store = phone();
    await store.load();
    await store.sync();
    expect(account.saved.toSet(), {box.id, rain.id});
    expect(store.value, {box.id, rain.id});
  });

  test('another account on the same phone starts from its own saves', () async {
    final store = phone();
    await store.load();
    await store.toggle(box);
    await store.sync();

    user = 'user-b';
    final other = _Account()..saved.add(rain.id);
    account = other;
    final next = phone(); // same phone, prefs carried over
    await next.load();
    await next.sync();
    expect(next.value, {rain.id});
    expect(other.saved, [rain.id], reason: 'user A\'s save not copied');
  });

  test('signed out, saves stay on the phone and nothing is sent', () async {
    user = null;
    final store = phone();
    await store.load();
    await store.toggle(box);
    await store.sync();
    expect(store.isSaved(box), isTrue);
    expect(account.calls, 0);
  });

  test('coming back to the app syncs at most hourly', () async {
    final store = phone();
    await store.load();
    await store.sync();
    final calls = account.calls;
    await store.syncIfStale();
    expect(account.calls, calls);
  });
}
