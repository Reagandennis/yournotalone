import 'package:flutter/material.dart';

import '../brand.dart';
import '../cbt/cbt_catalog.dart';
import '../cbt/cbt_content.dart';
import '../cbt/cbt_screen.dart';
import '../discover/content_index.dart';
import '../discover/content_widgets.dart';
import '../discover/usage_store.dart';
import '../journal/journal_hub_screen.dart';
import '../meditation/meditations_screen.dart';
import '../recovery/recovery_screen.dart';
import '../sleep/sleep_catalog.dart';
import '../sleep/sleep_content.dart';
import '../sleep/sleep_screen.dart';
import '../sounds/sounds_screen.dart';
import '../stress/stress_catalog.dart';
import '../stress/stress_content.dart';
import '../stress/stress_screen.dart';
import '../therapy/therapy_screen.dart';
import '../toolkit/toolkit_hub.dart';
import 'home_ui.dart';

/// Soft grey used for the tiles and panels on this tab: a wash of ink over
/// the page, made opaque so the floating card hides what scrolls under it.
Color _tile(BrandColors c) =>
    Color.alphaBlend(c.tint(Pillars.black, 0.08), c.background);

/// Solid card fills that carry their own text and art; the same in both
/// modes.
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

/// A collection: everything of some kinds in the index, so the count can
/// never drift from what the list it opens offers.
class _Collection {
  const _Collection(
    this.title,
    this.unit,
    this.color,
    this.kinds,
    this.subtitle,
  );

  final String title;
  final String unit;

  /// The pillar colour of whatever the collection holds.
  final Color color;
  final Set<ContentKind> kinds;

  /// The intro on the list it opens.
  final String subtitle;

  List<ContentItem> get items => [
    for (final item in contentIndex)
      if (kinds.contains(item.kind)) item,
  ];

  /// The card's fill. Ink flips to off-white in the dark, like the logo's
  /// black pillar; the coloured cards look the same in both modes.
  Color fill(BrandColors c) => color == Pillars.black ? c.ink : color;

  /// Ink on yellow (in both modes), white on the other colours, and the
  /// reverse of the ink card on it: keeps the text readable.
  Color foreground(BrandColors c) => switch (color) {
    _cardYellow => BrandColors.light.ink,
    Pillars.black => c.onInk,
    _ => Colors.white,
  };
}

const _collections = <_Collection>[
  _Collection('Breathing exercises', 'rhythms', _cardBlue, {
    ContentKind.breathing,
  }, 'A few minutes of paced breathing, each with its own rhythm.'),
  _Collection('Guided meditations', 'sessions', Pillars.black, {
    ContentKind.meditation,
  }, 'Timed sessions with gentle guidance on screen.'),
  _Collection('Wellbeing sounds', 'loops', _cardYellow, {
    ContentKind.sound,
  }, 'Ambient sound for focus, sleep and calm. Plays on with the screen off.'),
  _Collection('Journal prompts', 'prompts', _cardRed, {
    ContentKind.prompt,
  }, 'A first line to get you writing, so the page is never blank.'),
  _Collection('Short reads', 'reads', _cardBlue, {
    ContentKind.lesson,
  }, 'The ideas behind the tools, a few minutes each.'),
  _Collection('Recovery tools', 'tools', Pillars.black, {
    ContentKind.recovery,
  }, 'For cravings and the commitments you\'re keeping.'),
];

/// Explore tab: search, browse by need, the four pillars as tiles,
/// featured programmes, the collections, and a way to book a human
/// therapist.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  /// "What do you need right now?": one chip per need, each opening
  /// everything tagged for it.
  Widget _needs(BuildContext context) {
    final c = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'What do you need right now?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
        ),
        SizedBox(
          height: 18 + 22 * MediaQuery.textScalerOf(context).scale(1),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: Need.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final need = Need.values[i];
              return FilterPill(
                label: need.label,
                icon: need.icon,
                color: need.color,
                selected: false,
                onTap: () => Navigator.of(context).push(
                  ContentListScreen.route(ContentListScreen.forNeed(need)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar(BuildContext context) {
    final c = context.brand;
    return Material(
      color: _tile(c),
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () =>
            showSearch(context: context, delegate: _ExploreSearchDelegate()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 22, color: c.ink),
              const SizedBox(width: 12),
              Text(
                'Search',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillarTile(BuildContext context, _Pillar pillar) {
    final c = context.brand;
    return Material(
      color: _tile(c),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
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
    final c = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: _tile(c),
        borderRadius: BorderRadius.circular(_radius),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Our featured programs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Step-by-step tools and short reads, each built around one '
              'thing.',
              style: TextStyle(fontSize: 12, color: c.ink, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          for (final program in _programs) _programCard(context, program),
        ],
      ),
    );
  }

  Widget _collectionCard(BuildContext context, _Collection collection) {
    final c = context.brand;
    final foreground = collection.foreground(c);
    final items = collection.items;
    final fresh = items.any((i) => i.isNewAt(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: collection.fill(c),
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: () => Navigator.of(context).push(
            ContentListScreen.route(
              ContentListScreen(
                title: collection.title,
                subtitle: collection.subtitle,
                items: items,
                source: 'collection:${collection.unit}',
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              collection.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ),
                          if (fresh) ...[
                            const SizedBox(width: 8),
                            const NewChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} ${collection.unit} · '
                        '${countLine(items)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookSession(BuildContext context) {
    final c = context.brand;
    return Material(
      color: _tile(c),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Speak to a human therapist',
                      style: TextStyle(fontSize: 12.5, color: c.ink),
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
        const SizedBox(height: 20),
        _needs(context),
        const SizedBox(height: 22),
        _pillarGrid(context),
        const SizedBox(height: 20),
        _featuredPanel(context),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'All collections',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.brand.ink,
            ),
          ),
        ),
        for (final collection in _collections)
          _collectionCard(context, collection),
      ],
    );
  }
}

/// Whether [item] matches [query]: title, meta, blurb, or a need it's
/// tagged for ("sleep", "anxious").
bool _matches(ContentItem item, String query) =>
    item.title.toLowerCase().contains(query) ||
    item.meta.toLowerCase().contains(query) ||
    item.blurb.toLowerCase().contains(query) ||
    item.needs.any((n) => n.label.toLowerCase().contains(query));

/// Searches the whole index. A result opens the item itself (through the
/// usual Premium check), not the list it lives in.
class _ExploreSearchDelegate extends SearchDelegate<void> {
  _ExploreSearchDelegate() : super(searchFieldLabel: 'Search');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.brand;
    return theme.copyWith(
      inputDecorationTheme: InputDecorationThemeData(
        border: InputBorder.none,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 16),
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          color: c.ink,
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
  Widget buildResults(BuildContext context) => _body(context);

  @override
  Widget buildSuggestions(BuildContext context) => _body(context);

  Widget _body(BuildContext context) =>
      query.trim().isEmpty ? _start(context) : _list(context);

  Widget _heading(BuildContext context, String text, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.brand.ink,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      );

  /// Before anything is typed: recent searches, then a nudge by need.
  Widget _start(BuildContext context) {
    final c = context.brand;
    return FutureBuilder<List<String>>(
      future: UsageStore.instance.recentSearches(),
      builder: (context, snapshot) {
        final recent = snapshot.data ?? const <String>[];
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (recent.isNotEmpty) ...[
              _heading(
                context,
                'Recent',
                trailing: TextButton(
                  onPressed: () async {
                    await UsageStore.instance.clearSearches();
                    // Rebuild the suggestions with the list gone.
                    query = '';
                    if (context.mounted) showSuggestions(context);
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 13)),
                ),
              ),
              for (final r in recent)
                ListTile(
                  leading: Icon(Icons.history_rounded, color: c.textMuted),
                  title: Text(r, style: TextStyle(fontSize: 15, color: c.ink)),
                  onTap: () {
                    query = r;
                    showResults(context);
                  },
                ),
            ],
            _heading(context, 'Try searching for'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final need in Need.values)
                    FilterPill(
                      label: need.label,
                      icon: need.icon,
                      color: need.color,
                      selected: false,
                      onTap: () {
                        close(context, null);
                        Navigator.of(context).push(
                          ContentListScreen.route(
                            ContentListScreen.forNeed(need),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final c = context.brand;
    final q = query.trim().toLowerCase();
    final hits = [
      for (final item in contentIndex)
        if (_matches(item, q)) item,
    ];
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing matches that yet.',
            style: TextStyle(color: c.textMuted, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final item = hits[i];
        final locked = item.premium && !isPremiumUser();
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _tile(c),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 20, color: c.ink),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
              ),
              if (locked) ...[const SizedBox(width: 6), const PremiumChip()],
            ],
          ),
          subtitle: Text(
            item.meta,
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
          onTap: () {
            UsageStore.instance.recordSearch(query);
            close(context, null);
            openContent(context, item, source: 'search');
          },
        );
      },
    );
  }
}
