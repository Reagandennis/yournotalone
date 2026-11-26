import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/auth/auth_ui.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/journal/journal_drafts.dart';
import 'package:yournotalone/journal/journal_editor_screen.dart';
import 'package:yournotalone/journal/journal_repository.dart';
import 'package:yournotalone/journal/journal_screen.dart';

/// A journal that keeps entries in memory, and fails while [offline].
class _FakeJournal extends JournalRepository {
  var offline = false;
  final created = <(String?, String)>[];

  @override
  Future<void> create({String? title, required String content}) async {
    if (offline) throw Exception('offline');
    created.add((title, content));
  }

  /// Set to make updates find the entry deleted, or saved elsewhere.
  var gone = false;
  JournalEntry? newer;
  final updates = <(String, String?)>[];

  @override
  Future<void> update(String id,
      {String? title, required String content, String? baseVersion}) async {
    if (offline) throw Exception('offline');
    if (gone) throw JournalEntryMissing(id);
    if (newer case final current?
        when baseVersion != current.baseVersion) {
      throw JournalEntryConflict(current);
    }
    updates.add((content, baseVersion));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  /// A page with an Open button that pushes a fresh [editor] each time, so
  /// leaving it shows.
  Widget host(Widget Function() editor) => MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => editor()),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

  JournalDrafts draftsFor(String user) => JournalDrafts(userId: () => user);

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// Types into the entry and waits long enough for the draft to be kept.
  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pump(const Duration(seconds: 1));
  }

  const draftOffer = 'Pick up where you left off?';

  testWidgets('journal list shows a friendly error when offline',
      (tester) async {
    await tester.pumpWidget(wrap(const JournalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Couldn\'t load your journal.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('editor enables save only once there is content',
      (tester) async {
    await tester.pumpWidget(wrap(const JournalEditorScreen()));
    await tester.pumpAndSettle();

    ElevatedButton saveButton() => tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Save entry'),
            matching: find.byType(ElevatedButton),
          ),
        );
    expect(saveButton().onPressed, isNull);

    await tester.enterText(
      find.byType(TextField).last,
      'Today was heavy, but I made it.',
    );
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('gratitude prompt pre-fills the editor', (tester) async {
    await tester.pumpWidget(wrap(const JournalEditorScreen(
      initialTitle: 'Gratitude',
      initialContent: 'Today, I\'m grateful for ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Gratitude'), findsOneWidget);
    expect(find.text('Today, I\'m grateful for '), findsOneWidget);
  });

  testWidgets('an unsaved entry is kept on the phone and offered back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final journal = _FakeJournal();
    await tester.pumpWidget(host(() =>
        JournalEditorScreen(repository: journal, drafts: draftsFor('amina'))));
    await open(tester);
    await write(tester, 'Couldn\'t sleep again');

    // The app is closed without saving.
    await tester.pumpWidget(const SizedBox());

    // Someone else signed in on this phone isn't offered it…
    await tester.pumpWidget(host(() =>
        JournalEditorScreen(repository: journal, drafts: draftsFor('bo'))));
    await open(tester);
    expect(find.text(draftOffer), findsNothing);
    await tester.pumpWidget(const SizedBox());

    // …and nor is editing an entry that already exists.
    final entry = JournalEntry(
      id: 'entry-1',
      title: null,
      content: 'An older entry',
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );
    await tester.pumpWidget(host(() => JournalEditorScreen(
          entry: entry,
          repository: journal,
          drafts: draftsFor('amina'),
        )));
    await open(tester);
    expect(find.text(draftOffer), findsNothing);
    expect(find.text('An older entry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    // The next new entry offers it back.
    await tester.pumpWidget(host(() =>
        JournalEditorScreen(repository: journal, drafts: draftsFor('amina'))));
    await open(tester);
    expect(find.text(draftOffer), findsOneWidget);
    await tester.tap(find.text('Carry on writing'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t sleep again'), findsOneWidget);

    // Saving forgets the draft.
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(journal.created.single.$2, 'Couldn\'t sleep again');
    expect(find.text('Open'), findsOneWidget);
    await open(tester);
    expect(find.text(draftOffer), findsNothing);
  });

  testWidgets('leaving an unsaved entry asks; Discard forgets the draft',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host(() => JournalEditorScreen(
          repository: _FakeJournal(),
          drafts: draftsFor('amina'),
        )));
    await open(tester);
    await write(tester, 'Half a thought');

    await tester.tap(find.byType(BackChip));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Keep writing'));
    await tester.pumpAndSettle();
    expect(find.text('Half a thought'), findsOneWidget);

    await tester.tap(find.byType(BackChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);

    await open(tester);
    expect(find.text(draftOffer), findsNothing);
    expect(find.text('Half a thought'), findsNothing);
  });

  testWidgets('a save that fails offline keeps the entry as a draft',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final journal = _FakeJournal()..offline = true;
    await tester.pumpWidget(host(() =>
        JournalEditorScreen(repository: journal, drafts: draftsFor('amina'))));
    await open(tester);
    await write(tester, 'Today was a lot');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn\'t save your entry — check your connection.'),
      findsOneWidget,
    );
    expect(find.text('Today was a lot'), findsOneWidget);

    // The phone dies before it can be saved; next time it's still there.
    await tester.pumpWidget(const SizedBox());
    journal.offline = false;
    await tester.pumpWidget(host(() =>
        JournalEditorScreen(repository: journal, drafts: draftsFor('amina'))));
    await open(tester);
    expect(find.text(draftOffer), findsOneWidget);

    // Discard on the offer throws it away for good.
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Today was a lot'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('journal.draft')), isEmpty);
  });

  group('editing an entry saved or deleted elsewhere', () {
    final entry = JournalEntry(
      id: 'entry-1',
      title: null,
      content: 'Before',
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1, 9),
      version: '2026-11-01T09:00:00.000000+00:00',
    );

    Widget editing(_FakeJournal journal, {JournalEntry? opened}) => host(
          () => JournalEditorScreen(
            entry: opened ?? entry,
            repository: journal,
            drafts: draftsFor('amina'),
          ),
        );

    testWidgets('a deleted entry keeps the words and can be saved as new',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final journal = _FakeJournal()..gone = true;
      await tester.pumpWidget(editing(journal));
      await open(tester);
      await write(tester, 'After');
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      // Not reported as saved: still here, with a way to keep it.
      expect(find.text('After'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('This entry was deleted'), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save as a new entry'),
      ));
      await tester.pumpAndSettle();
      expect(journal.created.single.$2, 'After');
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a save over a newer version asks; replacing saves on it',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final newer = JournalEntry(
        id: entry.id,
        title: null,
        content: 'From the other phone',
        createdAt: entry.createdAt,
        updatedAt: DateTime.utc(2026, 11, 1, 10),
        version: '2026-11-01T10:00:00.000000+00:00',
      );
      final journal = _FakeJournal()..newer = newer;
      await tester.pumpWidget(editing(journal));
      await open(tester);
      await write(tester, 'Mine');
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(journal.updates, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);

      expect(find.text('This entry changed on another device'), findsOneWidget);
      // "Replace": mine replaces the newer version, knowingly.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Replace'),
      ));
      await tester.pumpAndSettle();
      expect(journal.updates.single, ('Mine', newer.baseVersion));
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a draft older than the saved entry is not restored silently',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final drafts = draftsFor('amina');
      await drafts.save(
        entry.id,
        JournalDraft(title: '', content: 'Old draft', base: entry.baseVersion),
      );
      // The entry was saved again on another phone since.
      final saved = JournalEntry(
        id: entry.id,
        title: null,
        content: 'Newer words',
        createdAt: entry.createdAt,
        updatedAt: DateTime.utc(2026, 11, 2),
        version: '2026-11-02T00:00:00.000000+00:00',
      );
      await tester.pumpWidget(editing(_FakeJournal(), opened: saved));
      await open(tester);
      expect(find.text(draftOffer), findsOneWidget);
      expect(find.textContaining('changed after this draft was written'),
          findsOneWidget);

      // Dismissed with back: nothing restored.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Newer words'), findsOneWidget);
      expect(find.text('Old draft'), findsNothing);
    });

    testWidgets('a draft keeps the version it was written against',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final drafts = draftsFor('amina');
      await tester.pumpWidget(editing(_FakeJournal()));
      await open(tester);
      await write(tester, 'Half done');
      final kept = await drafts.load(entry.id);
      expect(kept?.content, 'Half done');
      expect(kept?.base, entry.baseVersion);
    });
  });
}
