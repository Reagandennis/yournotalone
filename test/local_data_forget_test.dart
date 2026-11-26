import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/account/local_data.dart';

/// Deleting an account leaves nothing of that person's on the phone, even
/// what stores keep per account under their own keys.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String pending(String user, String id) => jsonEncode({
    'id': id,
    'user_id': user,
    'kind': 'sound',
    'slug': 'rain',
    'title': 'Rain',
    'minutes': 5.0,
    'completed_at': '2026-11-01T10:00:00.000Z',
  });

  test('forget removes drafts, unsent sessions and saves of that account',
      () async {
    SharedPreferences.setMockInitialValues({
      'local.owner': 'ana',
      'journal.draft.ana.new': '{"title":"","content":"private"}',
      'journal.draft.ana.entry-1': '{"title":"","content":"more"}',
      'journal.draft.ben.new': '{"title":"","content":"ben\'s"}',
      'practice_pending_sessions': [pending('ana', '1'), pending('ben', '2')],
      'discover.saved': ['sound:Rainfall'],
      'discover.saved.pending': '{}',
      'discover.saved.owner': 'ana',
      'appearance': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    LocalData.instance.debugUse(prefs);

    LocalData.instance.forget('ana');

    final keys = prefs.getKeys();
    expect(keys.where((k) => k.startsWith('journal.draft.ana.')), isEmpty);
    expect(keys, contains('journal.draft.ben.new'));
    final left = prefs.getStringList('practice_pending_sessions')!;
    expect(left, hasLength(1));
    expect((jsonDecode(left.single) as Map)['user_id'], 'ben');
    expect(keys.where((k) => k.startsWith('discover.saved')), isEmpty);
    expect(prefs.getString('appearance'), 'dark', reason: 'the phone\'s');
  });

  test('someone else\'s saves stay', () async {
    SharedPreferences.setMockInitialValues({
      'local.owner': 'ana',
      'discover.saved': ['sound:Rainfall'],
      'discover.saved.owner': 'ben',
    });
    final prefs = await SharedPreferences.getInstance();
    LocalData.instance.debugUse(prefs);

    LocalData.instance.forget('ana');
    expect(prefs.getStringList('discover.saved'), ['sound:Rainfall']);
  });
}
