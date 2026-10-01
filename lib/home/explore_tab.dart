import 'package:flutter/material.dart';

import '../brand.dart';
import '../cbt/cbt_catalog.dart';
import '../cbt/cbt_content.dart';
import '../cbt/cbt_screen.dart';
import '../journal/journal_hub_screen.dart';
import '../journal/journal_prompts.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditations_screen.dart';
import '../recovery/recovery_screen.dart';
import '../sleep/sleep_catalog.dart';
import '../sleep/sleep_content.dart';
import '../sleep/sleep_screen.dart';
import '../sounds/sounds_catalog.dart';
import '../sounds/sounds_screen.dart';
import '../stress/stress_catalog.dart';
import '../stress/stress_content.dart';
import '../stress/stress_screen.dart';
import '../therapy/therapy_screen.dart';
import '../toolkit/toolkit_hub.dart';

/// Soft grey used for the tiles and panels on this tab.
const _tile = Color(0xFFE7E7E7);
const _cardRed = Color(0xFFC53C26);
const _cardBlue = Color(0xFF3E6AB7);
const _cardYellow = Color(0xFFF4BB40);
const _radius = 16.0;

/// One of the four pillars, shown as a tile in the grid at the top.
class _Pillar {
  const _Pillar(this.title, this.image, this.open);

  final String title;
  final String image;
  final WidgetBuilder open;
}

/// Illustrations lifted from the Canva design, in `assets/explore/`.
String _art(String name) => 'assets/explore/$name.png';
const _bookArt = 'assets/explore/book.png';

final _pillars = <_Pillar>[
  _Pillar('Meditate', _art('meditate'), (_) => const MeditationsScreen()),
  _Pillar('Well being', _art('wellbeing'), (_) => const SoundsScreen()),
  _Pillar('Journal & mood', _art('journal'), (_) => const JournalHubScreen()),
  _Pillar('Recovery tools', _art('recovery'), (_) => const RecoveryScreen()),
];

/// A featured programme: a full-width coloured card inside the grey panel.
class _Program {
  const _Program(
    this.title,
    this.blurb,
    this.image,
    this.color,
    this.open, {
    required this.counts,
  });

  final String title;
  final String blurb;
  final String image;
  final Color color;
  final RouteBuilder open;

  /// "1 free · 8 Premium", counted from the programme's tools and reads.
  final String counts;
}

String _programCounts(Iterable<bool> tools, Iterable<bool> lessons) =>
    ToolkitHub.countLine([...tools, ...lessons]);

typedef RouteBuilder = Route<void> Function();

final _programs = <_Program>[
  _Program(
    'CBT for Therapy',
    'Tools and reads for anxious & low thoughts',
    _art('cbt'),
    _cardRed,
    CbtScreen.route,
    counts: _programCounts(
      cbtTools.map((t) => t.premium),
      cbtLessons.map((l) => l.premium),
    ),
  ),
  _Program(
    'Sleep better',
    'A wind-down, the 20-minute rule, a sleep diary',
    _art('sleep'),
    _cardBlue,
    SleepScreen.route,
    counts: _programCounts(
      sleepTools.map((t) => t.premium),
      sleepLessons.map((l) => l.premium),
    ),
  ),
  _Program(
    'Manage stress',
    'Bring the body down, then sort the load',
    _art('stress'),
    _cardYellow,
    StressScreen.route,
    counts: _programCounts(
      stressTools.map((t) => t.premium),
      stressLessons.map((l) => l.premium),
    ),
  ),
];

/// A collection: everything of one kind, counted from the real catalogues
/// so the number can never drift from what the destination offers.
class _Collection {
  const _Collection(this.title, this.count, this.unit, this.color, this.open);

  final String title;
  final int count;
  final String unit;

  /// The pillar colour of whatever the collection holds.
  final Color color;
  final WidgetBuilder open;

  /// Ink on yellow, white on everything else: keeps the text readable.
  Color get foreground => color == _cardYellow ? Brand.ink : Colors.white;
}

final _collections = <_Collection>[
  _Collection(
    'Breathing exercises',
    breathPatterns.length,
    'rhythms',
    _cardBlue,
    (_) => const MeditationsScreen(),
  ),
  _Collection(
    'Guided meditations',
    meditations.length,
    'sessions',
    Brand.ink,
    (_) => const MeditationsScreen(),
  ),
  _Collection(
    'Wellbeing sounds',
    soundsCatalog.length,
    'loops',
    _cardYellow,
    (_) => const SoundsScreen(),
  ),
  _Collection(
    'Journal prompts',
    journalPrompts.length,
    'prompts',
    _cardRed,
    (_) => const JournalHubScreen(),
  ),
];

/// Explore tab: search, the four pillars as tiles, featured programmes,
/// the collections, and a way to book a human therapist.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  Widget _searchBar(BuildContext context) {
    return Material(
      color: _tile,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () =>
            showSearch(context: context, delegate: _ExploreSearchDelegate()),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 22, color: Brand.ink),
              SizedBox(width: 12),
              Text(
                'Search',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Brand.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillarTile(BuildContext context, _Pillar pillar) {
    return Material(
      color: _tile,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () => _push(context, pillar.open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Image.asset(pillar.image, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pillar.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillarGrid(BuildContext context) {
    Widget row(_Pillar a, _Pillar b) => Row(
      children: [
        Expanded(child: _pillarTile(context, a)),
        const SizedBox(width: 12),
        Expanded(child: _pillarTile(context, b)),
      ],
    );
    return Column(
      children: [
        row(_pillars[0], _pillars[1]),
        const SizedBox(height: 12),
        row(_pillars[2], _pillars[3]),
      ],
    );
  }

  Widget _programCard(BuildContext context, _Program program) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: program.color,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: () => Navigator.of(context).push(program.open()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        program.blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        program.counts,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(program.image, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featuredPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(_radius),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Our featured programs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'A list of our featured content to get the most of your day '
              'started',
              style: TextStyle(fontSize: 12, color: Brand.ink, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          for (final program in _programs) _programCard(context, program),
        ],
      ),
    );
  }

  Widget _collectionCard(BuildContext context, _Collection collection) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: collection.color,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: () => _push(context, collection.open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: collection.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${collection.count} ${collection.unit}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: collection.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: collection.foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookSession(BuildContext context) {
    return Material(
      color: _tile,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () => Navigator.of(context).push(TherapyScreen.route()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Image.asset(_bookArt, fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Speak to a human therapist',
                      style: TextStyle(fontSize: 12.5, color: Brand.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Room left under the list so the last collection can scroll clear of
  /// the floating card.
  static const _floatingCardClearance = 96.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _list(context),
        Positioned(
          left: 18,
          right: 18,
          bottom: 12,
          child: _bookSession(context),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, _floatingCardClearance),
      children: [
        _searchBar(context),
        const SizedBox(height: 18),
        _pillarGrid(context),
        const SizedBox(height: 20),
        _featuredPanel(context),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'All collections',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
        ),
        for (final collection in _collections)
          _collectionCard(context, collection),
      ],
    );
  }
}

/// One thing the search can find, and where opening it leads.
class _SearchItem {
  const _SearchItem(this.title, this.meta, this.icon, this.open);

  final String title;
  final String meta;
  final IconData icon;
  final WidgetBuilder open;
}

/// Built from the real catalogues, so the search covers exactly what the
/// app offers today. Results open the list the item lives in, which keeps
/// the usual Premium gating in place.
final _searchItems = <_SearchItem>[
  for (final p in breathPatterns)
    _SearchItem(
      p.title,
      'Breathing · ${p.rhythmLabel}',
      Icons.air_rounded,
      (_) => const MeditationsScreen(),
    ),
  for (final m in meditations)
    _SearchItem(
      m.title,
      'Meditation · ${m.minutes} min',
      m.icon,
      (_) => const MeditationsScreen(),
    ),
  for (final s in soundsCatalog)
    _SearchItem(
      s.title,
      'Sound · ${s.category.label}',
      s.icon,
      (_) => const SoundsScreen(),
    ),
  for (final p in journalPrompts)
    _SearchItem(
      p.title,
      'Journal prompt',
      p.icon,
      (_) => const JournalHubScreen(),
    ),
  for (final t in cbtTools)
    _SearchItem(
      t.title,
      'CBT · ${t.minutes} min',
      t.icon,
      (_) => const CbtScreen(),
    ),
  for (final t in sleepTools)
    _SearchItem(
      t.title,
      'Sleep · ${t.meta ?? '${t.minutes} min'}',
      t.icon,
      (_) => const SleepScreen(),
    ),
  for (final t in stressTools)
    _SearchItem(
      t.title,
      'Stress · ${t.meta ?? '${t.minutes} min'}',
      t.icon,
      (_) => const StressScreen(),
    ),
  _SearchItem(
    'Urge surfing',
    'Recovery · 8 min',
    Icons.surfing_rounded,
    (_) => const RecoveryScreen(),
  ),
  _SearchItem(
    'HALT check',
    'Recovery',
    Icons.psychology_alt_rounded,
    (_) => const RecoveryScreen(),
  ),
  _SearchItem(
    'Play the tape forward',
    'Recovery',
    Icons.movie_filter_rounded,
    (_) => const RecoveryScreen(),
  ),
  _SearchItem(
    'My commitments',
    'Recovery · streaks',
    Icons.verified_rounded,
    (_) => const RecoveryScreen(),
  ),
  _SearchItem(
    'Milestones',
    'Recovery',
    Icons.emoji_events_rounded,
    (_) => const RecoveryScreen(),
  ),
  _SearchItem(
    'Trigger tracker',
    'Recovery',
    Icons.bolt_rounded,
    (_) => const RecoveryScreen(),
  ),
];

class _ExploreSearchDelegate extends SearchDelegate<void> {
  _ExploreSearchDelegate() : super(searchFieldLabel: 'Search');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: const InputDecorationThemeData(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Brand.textMuted, fontSize: 16),
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          color: Brand.ink,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final q = query.trim().toLowerCase();
    final hits = q.isEmpty
        ? _searchItems
        : _searchItems
              .where(
                (i) =>
                    i.title.toLowerCase().contains(q) ||
                    i.meta.toLowerCase().contains(q),
              )
              .toList();
    if (hits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nothing matches that yet.',
            style: TextStyle(color: Brand.textMuted, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final item = hits[i];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _tile,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 20, color: Brand.ink),
          ),
          title: Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Brand.ink,
            ),
          ),
          subtitle: Text(
            item.meta,
            style: const TextStyle(fontSize: 12.5, color: Brand.textMuted),
          ),
          onTap: () {
            close(context, null);
            Navigator.of(context).push(MaterialPageRoute(builder: item.open));
          },
        );
      },
    );
  }
}
