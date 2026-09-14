import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_navigation.dart';
import '../brand.dart';
import '../care/therapist_sessions_screen.dart';
import '../notifications/local_notifications.dart';
import '../notifications/session_notifications.dart';
import '../therapy/therapy_screen.dart';
import 'explore_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';

/// Opens the screen a tapped session notification is about: a therapist's
/// sessions, or the client's therapy screen.
void openSessionScreen(String payload) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null ||
      Supabase.instance.client.auth.currentUser == null) {
    return;
  }
  navigator.push(
    MaterialPageRoute(
      builder: (_) => payload == 'therapist'
          ? const TherapistSessionsScreen()
          : const TherapyScreen(),
    ),
  );
}

/// The signed-in shell: bottom navigation between Home, Explore, and
/// Settings.
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
    final payload = LocalNotifications.takeLaunchPayload();
    if (payload != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => openSessionScreen(payload));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SessionNotifications.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: IndexedStack(
              index: _index,
              children: const [HomeTab(), ExploreTab(), SettingsTab()],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Brand.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
