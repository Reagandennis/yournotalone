import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_navigation.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../care/therapist_sessions_screen.dart';
import '../courses/course_progress.dart';
import '../discover/content_index.dart';
import '../discover/saved_store.dart';
import '../journal/journal_hub_screen.dart';
import '../l10n/l10n.dart';
import '../media/lapsed_downloads.dart';
import '../notifications/local_notifications.dart';
import '../notifications/notification_permission.dart';
import '../notifications/session_notifications.dart';
import '../recovery/recovery_screen.dart';
import '../reminders/reminders_service.dart';
import '../therapy/call_screen.dart';
import '../therapy/therapy_screen.dart';
import 'explore_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';

/// Opens the screen a tapped session notification is about: a therapist's
/// sessions, or the client's therapy screen.
///
/// If that screen is already open — the usual case, since people wait for
/// a session on it — it comes back to the front rather than being pushed
/// again on top of itself. If they're already in the call, nothing moves.
void openSessionScreen(String payload) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null ||
      Supabase.instance.client.auth.currentUser == null) {
    return;
  }
  if (payload.startsWith(reminderPayloadPrefix)) {
    openReminderTarget(
      navigator,
      payload.substring(reminderPayloadPrefix.length),
    );
    return;
  }
  if (appRoutes.isOpen(CallScreen.routeName)) return;
  final name = payload == 'therapist'
      ? TherapistSessionsScreen.routeName
      : TherapyScreen.routeName;
  if (appRoutes.isOpen(name)) {
    navigator.popUntil((route) => route.settings.name == name);
    return;
  }
  navigator.push(payload == 'therapist'
      ? TherapistSessionsScreen.route()
      : TherapyScreen.route());
}

/// Asks the shell to switch tab (0 Home, 1 Explore, 2 Settings), for
/// taps that arrive from outside it, like a notification.
final homeTabRequest = ValueNotifier<int?>(null);

/// Where a tapped daily reminder leads: the morning check-in to the mood
/// card on Home, the pledge to recovery, evening pages to the journal, and
/// wind-down straight into the wind-down plan.
void openReminderTarget(NavigatorState navigator, String kindName) {
  final kind = ReminderKind.values.asNameMap()[kindName];
  if (kind == null) return;
  Sentry.metrics.count('reminder.opened', 1, attributes: {
    'kind': SentryAttribute.string(kind.name),
  });
  if (appRoutes.isOpen(CallScreen.routeName)) return;
  navigator.popUntil((route) => route.isFirst);
  switch (kind) {
    case ReminderKind.checkin:
      homeTabRequest.value = 0;
    case ReminderKind.pledge:
      navigator.push(
        MaterialPageRoute(builder: (_) => const RecoveryScreen()),
      );
    case ReminderKind.journal:
      navigator.push(
        MaterialPageRoute(builder: (_) => const JournalHubScreen()),
      );
    case ReminderKind.windDown:
      final plan = contentIndex.firstWhere(
        (i) => i.id == 'tool:Wind-down plan',
      );
      openContent(navigator.context, plan, source: 'reminder:windDown');
  }
}

/// The signed-in shell: navigation between Home, Explore, and Settings —
/// a bottom bar on phones, a side rail where there's room.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Catch up on session news, and keep background checks in step with
    // whether there's a session to watch.
    SessionNotifications.instance.start();
    // People who signed up before the app asked, or who skipped the step:
    // the system prompt once, then never again from here.
    NotificationPermission.instance.promptIfNeverAsked();
    // Reminders set before they carried a payload learn where to lead.
    RemindersService.instance.refreshScheduled();
    SavedStore.instance.load();
    CourseStore.instance.load();
    homeTabRequest.addListener(_onTabRequest);
    // Premium ended a month ago with its downloads still here: ask once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askAboutDownloads());
    final payload = LocalNotifications.takeLaunchPayload();
    if (payload != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => openSessionScreen(payload));
    }
  }

  void _askAboutDownloads() {
    if (mounted) LapsedDownloads.instance.maybeAsk(context);
  }

  void _onTabRequest() {
    final index = homeTabRequest.value;
    if (index == null || !mounted) return;
    homeTabRequest.value = null;
    setState(() => _index = index);
  }

  @override
  void dispose() {
    homeTabRequest.removeListener(_onTabRequest);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SessionNotifications.instance.start();
      _askAboutDownloads();
    }
  }

  /// Keeps each tab's state (scroll position, filters) when the layout
  /// switches between the bottom bar and the side rail — an iPhone Duo
  /// unfolding, an iPad window being resized.
  final _tabsKey = GlobalKey();

  List<(IconData, IconData, String)> _destinations(BuildContext context) => [
    (Icons.home_outlined, Icons.home_rounded, context.l10n.shellTabHome),
    (
      Icons.explore_outlined,
      Icons.explore_rounded,
      context.l10n.shellTabExplore,
    ),
    (
      Icons.settings_outlined,
      Icons.settings_rounded,
      context.l10n.shellTabSettings,
    ),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = IndexedStack(
      key: _tabsKey,
      index: _index,
      children: const [HomeTab(), ExploreTab(), SettingsTab()],
    );
    final barColor = Theme.of(context).navigationBarTheme.backgroundColor;
    final border = BorderSide(color: context.brand.border, width: 1);

    // Wide: the tabs down the side, as on iPad and iPhone Duo, and the
    // whole width for the page.
    if (isWideLayout(context)) {
      return Scaffold(
        body: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                border: Border(right: border),
              ),
              child: SafeArea(
                right: false,
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.85,
                  destinations: [
                    for (final (icon, selected, label) in _destinations(
                      context,
                    ))
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                left: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kWideMaxWidth),
                    child: tabs,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(top: border),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final (icon, selected, label) in _destinations(context))
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      ),
    );
  }
}
